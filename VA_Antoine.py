import pandas as pd
import numpy as np
import statsmodels.api as sm
from linearmodels.iv import absorbing
from datetime import datetime

# Set paths and parameters
path = r"C:\Users\didac\Dropbox\Arbiter Research\Data analysis"
datapull = "20092024" # "18042024"  
datapull_lastmonth = 4
datapull_lastyear = 2024
min_med_cases = 2
min_cs_med = 2
small_cs = 35
pandemic_start = "15032020"
pandemic_end = "30082021"

# Load data
#df = pd.read_stata(f"{path}\Data_Clean\cases_cleaned_{datapull}.dta")
df = pd.read_csv(f"{path}\Data_Raw\cases_raw_{datapull}.csv", encoding = "ISO-8859-1")

## Drop new case types -TO BE CHANGED 
df = df[df['case_type'] != 'Judicial Review']
df = df[df['case_type'] != 'Constitution and Human Rights']

# Calculate days since appointment
df['med_appt_date'] = pd.to_datetime(df['mediator_appointment_date'], format='%Y-%m-%d')
df['days_since_appt'] = (datetime.strptime(datapull, "%d%m%Y") - df['med_appt_date']).dt.days

# Re-format conclusion date
df['concl_date'] = pd.to_datetime(df['conclusion_date'], format='%Y-%m-%d')

# Calculate days of mediation 
mask = (df['case_status'] != 'PENDING')
df.loc[mask, 'case_days_med'] = (df['concl_date'] - df['med_appt_date']).dt.days
mask = (df.case_days_med.isnull())
df.loc[mask, 'case_days_med'] = (datetime.strptime(datapull, "%d%m%Y") - df['med_appt_date']).dt.days

# Drop cases with certain "data issues"
df = df.dropna(subset=['mediator_id']) # Mediator id is missing 
df = df.dropna(subset=['med_appt_date']) # Mediator apptmnt date is missing 
df = df[df['case_days_med'] >= 0] # Case conclusion date before mediator assignment
pand = (df['med_appt_date'] > datetime.strptime(pandemic_start, "%d%m%Y")) & \
    (df['med_appt_date'] < datetime.strptime(pandemic_end, "%d%m%Y"))
df = df.loc[pand == False] # Pandemic cases

# Keep only mediators with at least X concluded total cases
concluded_df = df[df['case_status'] == 'CONCLUDED']
counts = concluded_df['mediator_id'].value_counts().reset_index()
counts.columns = ['mediator_id', 'concluded_count']
df = df.merge(counts, on='mediator_id', how='left')
df['concluded_count'].fillna(0, inplace=True)
df = df[df['concluded_count'] >= min_med_cases]
df = df.rename(columns={'concluded_count': 'totalcases'})

# Keep only courtstations with >= 'min_cs_med' mediators
df['ndistinct_med_cs'] = df.groupby('court_station').mediator_id.transform('nunique')
df = df[df['ndistinct_med_cs'] >= min_med_cases]

# Generate courtstation number of cases
df['totalcscases'] = df.groupby('court_station')['court_station'].transform('count')
mask = (df['totalcscases'] <= small_cs)

# Small courtstations group
df[['court_station']] = df[['court_station']].astype('str')
df.loc[mask, 'court_station'] = 'zzzSmall' # Group small CS's in the same category

# Generate quasi-year FE
df['appt_month'] =  df['med_appt_date'].dt.month
df['quasiyear'] = np.nan
for t in range(31):
    ub = datetime(int(datapull_lastyear - t), int(datapull_lastmonth), 30)
    lb = datetime(int(datapull_lastyear - t - 1), int(datapull_lastmonth), 30)
    mask = (df['med_appt_date'] <= ub) & (df['med_appt_date'] > lb)
    df.loc[mask, 'quasiyear'] = t
# Oldest 12 to 23 months: Group them together
oldest_qy = df['quasiyear'].max()
max_qy = df.loc[df['quasiyear'] == oldest_qy, 'med_appt_date'].max()
min_qy = df.loc[df['quasiyear'] == oldest_qy, 'med_appt_date'].min()
if (max_qy - min_qy).days < 365:
    df.loc[df['quasiyear'] == oldest_qy, 'quasiyear'] -= 1

# Milimani as omitted variable in reg
mask = (df['court_station'] == 'MILIMANI')
df.loc[mask, 'court_station'] = 'AAAMilimani'

## Simplify case types
df['casetype_simplified'] = df['case_type']
# Civil group
mask = (df['case_type'] == 'Civil Cases')
df.loc[mask, 'casetype_simplified'] = 'Civil group'
mask = (df['case_type'] == 'Civil Appeals')
df.loc[mask, 'casetype_simplified'] = 'Civil group'
# Family group
mask = (df['case_type'] == 'Divorce and Separation')
df.loc[mask, 'casetype_simplified'] = 'AAAFamily group'
mask = (df['case_type'] == 'Family Appeals')
df.loc[mask, 'casetype_simplified'] = 'AAAFamily group'
mask = (df['case_type'] == 'Family Miscellaneous')
df.loc[mask, 'casetype_simplified'] = 'AAAFamily group'
mask = (df['case_type'] == 'Succession (Probate & Administration - P&A)')
df.loc[mask, 'casetype_simplified'] = 'AAAFamily group'

# High court and court of appeal indicators
df['highcourt'] = 0
mask = (df['court_type'] == 'High Court')
df.loc[mask, 'highcourt'] = 1
df['courtofappeal'] = 0
mask = (df['court_type'] == 'Court of Appeal')
df.loc[mask, 'courtofappeal'] = 1


#%% Value Added Estimation

# Exclude cases that were appointed in the last X month
df_estim = df[df['days_since_appt'] >= 180]

# Keep only relevant variables with no missing info
df_estim = df_estim[['case_outcome_agreement', 'appt_month', 'quasiyear',
               'casetype_simplified', 'highcourt', 'courtofappeal',
               'court_station', 'referral_mode', 'mediator_id',
               'med_appt_date']].dropna()

# Transform numeric to categorical for estimation
df_estim[['mediator_id', 'appt_month', 'quasiyear']] = df[[
    'mediator_id', 'appt_month','quasiyear']].astype('category')

# Dependent, independent, and absorbed variables
depend = df_estim['case_outcome_agreement']
independ = sm.tools.tools.add_constant(df_estim[['appt_month', 'quasiyear',
                                          'casetype_simplified', 'highcourt',
                                          'courtofappeal', 'court_station',
                                          'referral_mode']])
catgrcl = df_estim[['mediator_id']]

# Estimation
model = absorbing.AbsorbingLS(depend, independ, absorb=catgrcl, drop_absorbed=True)
model_res = model.fit(cov_type='robust', debiased=True)
model_res = model.fit(cov_type='robust')

print(model_res.summary) # Print summary of results


#%% PREDICTIONS & RESIDUALS

# Recent cases
mask = (df['days_since_appt'] > 90) & (df['case_status'] == 'PENDING' ) # Do not use latest cases
df.loc[mask, 'case_outcome_agreement'] = 0

# Parameters
params = model_res.params
params = params.to_frame().reset_index()
params = params.rename(columns={"parameter": "value"})
params[['var', 'var_cat', 'empty']] = params['index'].str.split('.',expand=True)
params[['var']] = params[['var']].astype('str')
params = params.rename(columns={"parameter": "value"})
params.dtypes
df_estim.dtypes

# Parameters appt_month
params_appt_month = params[params['var'] == 'appt_month'] # Select only month params
params_appt_month = params_appt_month.rename(columns={"var_cat": 'appt_month', "value": 'appt_month_val'}) # Rename for merge
params_appt_month = params_appt_month[['appt_month', 'appt_month_val']]
params_appt_month[['appt_month']] = params_appt_month[['appt_month']].astype('float64') # Type for merge
params_appt_month.loc[-1] = [1,0]  # Add omitted variable

params_quasiyear = params[params['var'] == 'quasiyear'] 
params_quasiyear = params_quasiyear.rename(columns={"var_cat": 'quasiyear', "value": 'quasiyear_val'}) 
params_quasiyear = params_quasiyear[['quasiyear', 'quasiyear_val']]
params_quasiyear[['quasiyear']] = params_quasiyear[['quasiyear']].astype('float64') 
params_quasiyear.loc[-1] = [0,0]  # Add omitted variable

params_casetype_simplified = params[params['var'] == 'casetype_simplified'] 
params_casetype_simplified = params_casetype_simplified.rename(columns={"var_cat": 'casetype_simplified', "value": 'casetype_simplified_cat'}) 
params_casetype_simplified = params_casetype_simplified[['casetype_simplified', 'casetype_simplified_cat']]
params_casetype_simplified.loc[-1] = ['AAAFamily group',0]  

params_court_station = params[params['var'] == 'court_station'] # Select only month params
params_court_station = params_court_station.rename(columns={"var_cat": 'court_station', "value": 'court_station_cat'}) 
params_court_station = params_court_station[['court_station', 'court_station_cat']]
params_court_station.loc[-1] = ['AAAMilimani',0]  

params_referral_mode = params[params['var'] == 'referral_mode'] 
params_referral_mode = params_referral_mode.rename(columns={"var_cat": 'referral_mode', "value": 'referral_mode_cat'}) 
params_referral_mode = params_referral_mode[['referral_mode', 'referral_mode_cat']]
params_referral_mode.loc[-1] = ['Referred by Court',0]  

params_highcourt = params[params['var'] == 'highcourt'] 
params_highcourt = params_highcourt.rename(columns={"var": 'highcourt', "value": 'highcourt_val'}) 
params_highcourt = params_highcourt[['highcourt', 'highcourt_val']]
params_highcourt[['highcourt']] = 1
params_highcourt.loc[-1] = [0,0]  
params_highcourt[['highcourt']] = params_highcourt[['highcourt']].astype('float32') 

params_courtofappeal = params[params['var'] == 'courtofappeal'] 
params_courtofappeal = params_courtofappeal.rename(columns={"var": 'courtofappeal', "value": 'courtofappeal_val'}) 
params_courtofappeal = params_courtofappeal[['courtofappeal', 'courtofappeal_val']]
params_courtofappeal[['courtofappeal']] = 1
params_courtofappeal.loc[-1] = [0,0]  
params_courtofappeal[['courtofappeal']] = params_courtofappeal[['courtofappeal']].astype('float32') 

params_c = params[params['var'] == 'const'] 
params_c = params_c.rename(columns={"var": 'case_outcome_agreement', "value": 'c_val'}) 
params_c = params_c[['case_outcome_agreement', 'c_val']]
params_c[['case_outcome_agreement']] = 0
params_c.loc[-1] = [1,params_c['c_val'].mean()]  

# Merge the contribution of each parameter with each corresponding case
df = df.merge(params_appt_month, on='appt_month', how='left')
df = df.merge(params_quasiyear, on='quasiyear', how='left')
df = df.merge(params_casetype_simplified, on='casetype_simplified', how='left')
df = df.merge(params_court_station, on='court_station', how='left')
df = df.merge(params_referral_mode, on='referral_mode', how='left')
df = df.merge(params_highcourt, on='highcourt', how='left')
df = df.merge(params_courtofappeal, on='courtofappeal', how='left')
df = df.merge(params_c, on='case_outcome_agreement', how='left')

# Predictions
df['p_pred']= df[['appt_month_val', 'quasiyear_val', 'casetype_simplified_cat',
                  'court_station_cat', 'referral_mode_cat', 'highcourt_val', 
                  'courtofappeal_val', 'c_val']].sum(axis=1, skipna=False)

# Residuals
df["residuals"] = df["case_outcome_agreement"] - df["p_pred"]

# Keep only mediators for whom we know their VA
df = df.dropna(subset=["p_pred"])


#%% VALUE ADDED

# Calculate average residuals by mediator on their first and second half of cases
df['total_med_cases'] = df.groupby('mediator_id')['residuals'].transform('count') # Total mediator cases
df = df.sort_values(['mediator_id', 'med_appt_date', 'id'])
df['temp1'] = df.groupby('mediator_id')['residuals'].transform(
    lambda x: x.iloc[:len(x) // 2].mean())
df['average1'] = df.groupby('mediator_id')['temp1'].transform('mean') # Mean residuals first half
df['temp2'] = df.groupby('mediator_id')['residuals'].transform(
    lambda x: x.iloc[len(x) // 2:].mean())
df['average2'] = df.groupby('mediator_id')['temp2'].transform('mean') # Mean residuals second half

# Covariance of first and second half residuals, for the whole sample
average1_2 = df.groupby('mediator_id')[['average1', 'average2']].first().dropna()
cov_avgs = np.cov(average1_2['average1'], average1_2['average2'])[0, 1]
cov_avgs_sd = np.sqrt(cov_avgs) # Share
sigma = pd.DataFrame({'sigma': [cov_avgs_sd]})
sigma.to_csv(f"{path}/Output/Model/sigma_py_{datapull}.csv", index=False)

## Case prediction deviation by med (Residual - First/second half average residual)
df = df.sort_values(by=['mediator_id', 'med_appt_date', 'id'])
grouped = df.groupby('mediator_id') # Group by mediator_id
# Function to calculate means for the first and second halves
def calculate_half_means(group):
    n = len(group)
    first_half = group.iloc[:n // 2]
    second_half = group.iloc[n // 2:]
    # Calculate means for both halves
    first_half_mean = first_half['residuals'].mean()
    second_half_mean = second_half['residuals'].mean()
    # Assign the mean to each row based on whether it belongs to the first or second half
    group['half_mean'] = [first_half_mean] * len(first_half) + [second_half_mean] * len(second_half)
    return group
df = grouped.apply(calculate_half_means) # Apply the function to each group
df = df.reset_index(drop=True) # Remove the extra index introduced by groupby/apply
df['halfcases_dev'] = df['residuals'] - df['half_mean']

# Variance case prediction deviation
var_halfcases_dev = df['halfcases_dev'].std() ** 2 

# Variance residuals
var_residuals = df['residuals'].std() ** 2

# Factor for shrinkage
final_rst = var_residuals - cov_avgs - var_halfcases_dev

# Shrinkage
df['h'] = 1 / (final_rst + (var_halfcases_dev / (0.5 * df['total_med_cases'])))
df['h2'] = 1 / (2 * df['h'])
df['shrinkage'] = cov_avgs / (cov_avgs + df['h2'])
df['shrinkage_med'] = df.groupby('mediator_id')['shrinkage'].transform('mean')
df['naive_med'] = df.groupby('mediator_id')['residuals'].transform('mean')
df['va'] = df['shrinkage_med'] * df['naive_med']


#%% Export Results

# p's
pred_sample = df[['id', 'p_pred', 'case_outcome_agreement']]
pred_sample[['id', 'p_pred', 'case_outcome_agreement']].to_csv(
    f"{path}/Output/Model/p_pred_py_{datapull}.csv", index=False)

# VA
va_summary = df.groupby('mediator_id').agg({'va': 'first'}).reset_index()
va_summary.to_csv(f"{path}/Output/Model/VA_py_{datapull}.csv", index=False)

''' COMPARE WITH STATA
va_stata = pd.read_csv(f"{path}/Output/Model/VA_STATA_{datapull}.csv")
va_both = va_summary.merge(va_stata, on='mediator_id', how='left')
va_both = va_both[['mediator_id', 'va_new_x', 'va_new_y']]
va_both = va_both.rename(columns={'va_new_x': 'va_new_py', 'va_new_y': 'va_new_stata'}) # Rename for merge
va_both['diff'] = va_both['va_new_py'] - va_both['va_new_stata']
va_both.to_csv(f"{path}/Output/Model/VA_both_{datapull}.csv", index=False)
'''



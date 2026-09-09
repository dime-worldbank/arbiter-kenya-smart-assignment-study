'''
DESCRIPTION: This script estimates the mediator Value Added (VA) and case 
agreement probability net of mediator effects (p) using the raw cases data.
'''

# %% SET UP

import pandas as pd
import numpy as np
import statsmodels.api as sm
from linearmodels.iv import absorbing
from datetime import datetime
import time 
import calendar

startime = time.time()

# Set up dictionary
su = {
  'path': r'C:/Users/didac/Dropbox/Arbiter Research/Data analysis',
  'date': '20260513', #'20260219',       # DDMMYYYY of the datapull
  #'date_lastm': 7,          # MM of the datapull date
  #'date_lasty': 2025,       # YYYY of the datap_pull date
  'min_med_cases': 2,       # Minimum med cases to estimate the VA of med
  'min_cs_med': 2,          # Minimum cs meds to include the cs FE
  'small_cs': 35,           # Small courtstations threshold (indicator)
  'small_ct': 2,            # Small casetypes threshold (indicator)
  'pand_start': '15032020', # Start of pandemic (to drop days)
  'pand_end': '29082021',   # End of pandemic (to drop days)
}
date_dt = datetime.strptime(su['date'], "%Y%m%d")
su['date_lastm'] = date_dt.month
su['date_lasty'] = date_dt.year
#df = pd.read_csv('\Data analysis\Data_Raw\vw_deidentified_case_w_appointer_20250617.csv')

# Load main dataset (raw cases data)
df = pd.read_csv(f"{su['path']}/Data_Raw/vw_deidentified_case_w_appointer_{su['date']}.csv", 
                 encoding = "ISO-8859-1")


# %% DATA CLEANING
'''
This section has all the necessary data cleaning to be done before the
estimation. There are 3 parts in this section:
    - 1. Create the necessary variables for the rest of the script
    - 2. Drop the cases that we want to exclude from the estimation
    - 3. Modify some of the dependent variables to be used in the estimation
The order of the steps is important because when we create indicators to be 
used in the estimation the amount of observations left is relevant, so step 3
should always come after step 2. 
'''

### 1. Create necessary variables

# 1.1. Calculate days since appointment
df['med_appt_date'] = pd.to_datetime(df['mediator_appointment_date'], 
                                     format='%Y-%m-%d')
df['days_since_appt'] = (datetime.strptime(su['date'], "%Y%m%d") - 
                         df['med_appt_date']).dt.days 

# 1.2. Re-format conclusion date
df['concl_date'] = pd.to_datetime(df['conclusion_date'], format='%Y-%m-%d')

# 1.3. Calculate days of mediation 
df.loc[df['case_status'] != 'PENDING', 'case_days_med'] = \
    (df['concl_date'] - df['med_appt_date']).dt.days
df.loc[df.case_days_med.isnull(), 'case_days_med'] = \
    (datetime.strptime(su['date'], "%Y%m%d") - df['med_appt_date']).dt.days    

# 1.4. Simplify case types
df['casetype_simplified'] = df['case_type']
df.loc[df['case_type']=='Civil Cases', 'casetype_simplified'] = 'Civil group'
df.loc[df['case_type']=='Civil Appeals', 'casetype_simplified'] = 'Civil group'
df.loc[df['case_type']=='Divorce and Separation', 'casetype_simplified'] = 'AAAFamily group'
df.loc[df['case_type']=='Family Appeals', 'casetype_simplified'] = 'AAAFamily group'
df.loc[df['case_type']=='Family Miscellaneous', 'casetype_simplified'] = 'AAAFamily group'
df.loc[df['case_type']=='Succession (Probate & Administration - P&A)', 
                        'casetype_simplified'] = 'AAAFamily group'

df.loc[df['case_type']=='Commercial Cases', 'casetype_simplified'] = 'Commercial and tax group'
df.loc[df['case_type']=='Tax Appeals', 'casetype_simplified'] = 'Commercial and tax group'

# 1.5. High court indicator
df['highcourt'] = 0
df.loc[df['court_type'] == 'High Court', 'highcourt'] = 1

# 1.6. Court of appeal indicator
df['courtofappeal'] = 0
df.loc[df['court_type'] == 'Court of Appeal', 'courtofappeal'] = 1

# 1.7. Milimani as omitted variable in reg
mask = (df['court_station'] == 'MILIMANI')
df.loc[mask, 'court_station'] = 'AAAMilimani'

# 1.8. Generate quasi-year FE indicator
df['appt_month'] =  df['med_appt_date'].dt.month
df['quasiyear'] = np.nan
for t in range(31):   
    year_ub = int(su['date_lasty'] - t)
    month = int(su['date_lastm'])
    last_day_ub = calendar.monthrange(year_ub, month)[1]
    ub = datetime(year_ub, month, last_day_ub)
    year_lb = int(su['date_lasty'] - t - 1)
    last_day_lb = calendar.monthrange(year_lb, month)[1]
    lb = datetime(year_lb, month, last_day_lb)
    mask = (df['med_appt_date'] <= ub) & (df['med_appt_date'] > lb)
    df.loc[mask, 'quasiyear'] = t
# Oldest 12 to 23 months: Group them together
oldest_qy = df['quasiyear'].max()
max_qy = df.loc[df['quasiyear'] == oldest_qy, 'med_appt_date'].max()
min_qy = df.loc[df['quasiyear'] == oldest_qy, 'med_appt_date'].min()
if (max_qy - min_qy).days < 365:
    df.loc[df['quasiyear'] == oldest_qy, 'quasiyear'] -= 1
del ub, lb, mask, max_qy, min_qy, oldest_qy, t
df["quasiyear"].value_counts()
df["quasiyear"].value_counts(dropna=False)
'''
for t in range(31):
    print(t)
    ub = datetime(int(su['date_lasty'] - t), int(su['date_lastm']), 31)
    lb = datetime(int(su['date_lasty'] - t - 1), int(su['date_lastm']), 31)
    mask = (df['med_appt_date'] <= ub) & (df['med_appt_date'] > lb)
    df.loc[mask, 'quasiyear'] = t
'''

df_case = df 

### 2. Drop cases with "data issues" that should not be used in the estimation

# 2.1. Mediator id is missing -> Drop 
df = df.dropna(subset=['mediator_id'])  

# 2.2. Mediator apptmnt date is missing -> Drop
df = df.dropna(subset=['med_appt_date']) 

# 2.3. Case conclusion date is before mediator assignment -> Drop
df = df[df['case_days_med'] >= 0]        

# 2.4. Pandemic cases -> Drop
df = df.loc[~df['med_appt_date'].between(datetime.strptime(su['pand_start'], \
     "%d%m%Y"), datetime.strptime(su['pand_end'], "%d%m%Y"), inclusive="both")] 

### 3. Modify some of the dependent variables to be used in the estimation    

# 3.1. Create the "small mediators group" (mediators with less than X concluded 
#cases)
concltotal = df[df['case_status'] == 'CONCLUDED'].groupby('mediator_id').size()
df = df.merge(concltotal.rename('concltotal_med'), on='mediator_id', how='left')
df.loc[(df['concltotal_med']<su['min_med_cases']) | 
       (pd.isna(df['concltotal_med'])), 'mediator_id'] = -999
del concltotal

# 3.2. Create the "small courtstations group" (courtstations with less than X 
# concluded cases)
concltotal=df[df['case_status'] == 'CONCLUDED'].groupby('court_station').size()
df=df.merge(concltotal.rename('concltotal_cs'), on='court_station', how='left')
df['concltotal_cs'] = df['concltotal_cs'].fillna(0).astype(int)
df.loc[(df['concltotal_cs'] <=su['small_cs']) | (pd.isna(df['concltotal_cs'])),
       'court_station'] = 'zzzSmall'
del concltotal

# 3.3. Create the "small casetypes group" (casetypes with less than X 
# concluded cases)
concltotal = df[df['case_status'] == 'CONCLUDED'].groupby(
            'casetype_simplified').size()
df = df.merge(concltotal.rename('concltotal_ct'), on='casetype_simplified', 
              how='left')
df['concltotal_ct'] = df['concltotal_ct'].fillna(0).astype(int)
df.loc[df['concltotal_ct']<su['small_ct'], 'casetype_simplified'] = 'zzzSmall'
df_temp = df[['concltotal_ct', 'casetype_simplified']]
del concltotal

### 4. Add info to the df with all cases

# 4.1 Add small to df_case
df_case = df_case.set_index('id').copy()
df_case.update(df.set_index('id')
              [['mediator_id', 'court_station', 'casetype_simplified']])
df_case = df_case.reset_index()

# 4.2 Quasiyear. Waiting for appt -> Current quasiyear
mask = (df_case['quasiyear'].isna()
    & ~df_case['med_appt_date'].between(
        datetime.strptime(su['pand_start'], "%d%m%Y"),
        datetime.strptime(su['pand_end'], "%d%m%Y"),
        inclusive="both"))
df_case.loc[mask, 'quasiyear'] = df['quasiyear'].max()

# 4.3 Month - Waiting for appt -> Current month
date_dt = datetime.strptime(su['date'], "%Y%m%d")
date_lastm = date_dt.month
date_lasty = date_dt.year

mask = df_case['appt_month'].isna()
df_case.loc[mask, 'appt_month'] = date_lastm


#%% REGRESSION ESTIMATION
'''
Estimation dataset (df_estim): Only use for the estimation cases that were 
appointed more than 180 days before the data pull.

Dependent variable: 
    - case_outcome_agreement
Inependent variables:
    - appt_month (omitted: January)
    - quasiyear (omitted: Most recent)
    - casetype_simplified (omitted: Family group)
    - highcourt (omitted: No high court)
    - courtofappeal (omitted: No court of appeal)
    - court_station (omitted: Milimani)
    - referral_mode (omitted: Referred by court)
Absorbed: 
    - mediator_id
'''

# Exclude cases that were appointed in the last X month
df_estim = df[df['days_since_appt'] >= 180] # Exclude the last 6 months from the estimation

# Keep only relevant variables with no missing info
df_estim = df_estim[['case_outcome_agreement', 'appt_month', 'quasiyear',
               'casetype_simplified', 'highcourt', 'courtofappeal',
               'court_station', 'referral_mode', 'mediator_id',
               'med_appt_date']].dropna()
df_estim['case_outcome_agreement'].value_counts()

# Transform numeric to categorical for estimation
df_estim[['mediator_id', 'appt_month', 'quasiyear']] = df[[
    'mediator_id', 'appt_month','quasiyear']].astype('category')

# Dependent, independent, and absorbed variables
depend = df_estim['case_outcome_agreement']
independ = sm.tools.tools.add_constant(df_estim[['appt_month', 'quasiyear',
        'casetype_simplified', 'highcourt','courtofappeal', 'court_station',
        'referral_mode']])
catgrcl = df_estim[['mediator_id']]

# Estimation
model = absorbing.AbsorbingLS(depend, independ, absorb=catgrcl, 
                              drop_absorbed=True)
model_res = model.fit(cov_type='robust', debiased=True)
model_res = model.fit(cov_type='robust')

# Print summary of results
print(model_res.summary) 

del catgrcl, depend, independ

print(model_res.summary.as_latex())
#%% REGRESSION PREDICTIONS & RESIDUALS
'''
Manually get predictions "p" which are the fitted values of the regression.
Then calculate the residuals.

Out of sample predictions: In the estimation cases appointed less than 180 days
before the datapull are not used. But here we get the "p" for them anyway. 2
important points to consider though:
- Cases that were appointed less than 90 days ago but are still pending are
dropped, no prediction is made for them. 
- Cases that were appointed more than 90 days before the data pull and have
not concluded are considered as non-agreements -> Important for residuals.
'''

# Replace outcome = 0 if it lasted more than 90 and still pending
df.loc[(df['days_since_appt'] > 90) & (df['case_status'] == 'PENDING' ), 
       'case_outcome_agreement'] = 0
df_case.loc[(df_case['days_since_appt'] > 90) & (df_case['case_status'] == 'PENDING' ), 
       'case_outcome_agreement'] = 0

# Use only recent cases (appointed more than X days ago)
df = df[~((df['days_since_appt'] <= 90) & (df['case_status'] == 'PENDING'))]

# Parameters dataframe
params = model_res.params
params = params.to_frame().reset_index()
params = params.rename(columns={"parameter": "value"})
params[['var', 'var_cat', 'empty']] = params['index'].str.split('.',expand=True)
params[['var']] = params[['var']].astype('str')
params = params.rename(columns={"parameter": "value"})

# Parameters in separate entries in a dictionary
dependent = ['appt_month', 'quasiyear', 'casetype_simplified', 'court_station', 
             'referral_mode', 'highcourt', 'courtofappeal', 'const']
params_dict = {}
for x in dependent:
    params_dict[f"params_{x}"] = params[params['var'] == x]   
    params_dict[f"params_{x}"] = params_dict[f"params_{x}"].rename(columns={
        "var_cat": x, "value": f"{x}_val"})
    params_dict[f"params_{x}"] = params_dict[f"params_{x}"][[x, f"{x}_val"]]
    if x == 'highcourt' or x == 'courtofappeal':
        params_dict[f"params_{x}"][[x]] = 1 
        params_dict[f"params_{x}"].loc[-1] = [0, 0]
    if x == 'appt_month' or x == 'quasiyear' or x == 'highcourt' or \
        x == 'courtofappeal':
        params_dict[f"params_{x}"][[x]] = params_dict[
            f"params_{x}"][[x]].astype('float64')
del dependent
               
## Add omitted variable
params_dict['params_appt_month'].loc[-1] = [1, 0]  
params_dict['params_quasiyear'].loc[-1] = [0,0]  
params_dict['params_casetype_simplified'].loc[-1] = ['AAAFamily group',0]  
params_dict['params_court_station'].loc[-1] = ['AAAMilimani',0] 
params_dict['params_referral_mode'].loc[-1] = ['Referred by Court',0] 
params_dict['params_const'] = params_dict['params_const'].rename(columns={
    "const": 'case_outcome_agreement'})
params_dict['params_const']['case_outcome_agreement'] = 1
params_dict['params_const'].loc[-1] = [0,params_dict['params_const'][
    'const_val'].mean()] 
'''
# Merge the contribution of each parameter with each corresponding case
df = df.merge(params_dict['params_appt_month'], on='appt_month', how='left')
df = df.merge(params_dict['params_quasiyear'], on='quasiyear', how='left')
df = df.merge(params_dict['params_casetype_simplified'], 
              on='casetype_simplified', how='left')
df = df.merge(params_dict['params_court_station'], 
              on='court_station', how='left')
df = df.merge(params_dict['params_referral_mode'], 
              on='referral_mode', how='left')
df = df.merge(params_dict['params_highcourt'], on='highcourt', how='left')
df = df.merge(params_dict['params_courtofappeal'], 
              on='courtofappeal', how='left')
df = df.merge(params_dict['params_const'], 
              on='case_outcome_agreement', how='left')

# Predictions
df['p_pred']= df[['appt_month_val', 'quasiyear_val', 'casetype_simplified_val',
                  'court_station_val', 'referral_mode_val', 'highcourt_val', 
                  'courtofappeal_val', 'const_val']].sum(axis=1, skipna=True)

# Residuals
df["residuals"] = df["case_outcome_agreement"] - df["p_pred"]
df = df.sort_values(['id'])
'''

# Merge the contribution of each parameter with each corresponding case
df_case = df_case.merge(params_dict['params_appt_month'], on='appt_month', how='left')
df_case = df_case.merge(params_dict['params_quasiyear'], on='quasiyear', how='left')
df_case = df_case.merge(params_dict['params_casetype_simplified'], 
            on='casetype_simplified', how='left')
df_case = df_case.merge(params_dict['params_court_station'], 
            on='court_station', how='left')
df_case = df_case.merge(params_dict['params_referral_mode'], 
            on='referral_mode', how='left')
df_case = df_case.merge(params_dict['params_highcourt'], on='highcourt', how='left')
df_case = df_case.merge(params_dict['params_courtofappeal'], 
            on='courtofappeal', how='left')
df_case = df_case.merge(params_dict['params_const'], 
            on='case_outcome_agreement', how='left')

# Predictions
df_case['p_pred']= df_case[['appt_month_val', 'quasiyear_val', 'casetype_simplified_val',
                'court_station_val', 'referral_mode_val', 'highcourt_val', 
                'courtofappeal_val', 'const_val']].sum(axis=1, skipna=True)

# Courtstation
cs_small_value = df_case.loc[df_case['court_station'] == 'zzzSmall',
    'court_station_val'].iloc[0]
df_case['court_station_val'] = df_case['court_station_val'].fillna(cs_small_value)

#df_case[['appt_month_val', 'quasiyear_val', 'casetype_simplified_val',
#        'court_station_val', 'referral_mode_val', 'highcourt_val',
#        'courtofappeal_val', 'const_val']].isna().sum()

# Residuals
df_case["residuals"] = df_case["case_outcome_agreement"] - df_case["p_pred"]

# Merge back to df
df_alt = df 
df_alt['p_pred'] = df['id'].map(df_case.set_index('id')['p_pred'])
df_alt['residuals'] = df['id'].map(df_case.set_index('id')['residuals'])

# CHOOSE ALT
df =df_alt 


#####################

'''
cols = ['id', 'p_pred', 'residuals']

df1 = df[cols].sort_values('id').reset_index(drop=True)
df2 = df_alt[cols].sort_values('id').reset_index(drop=True)

print(df1.equals(df2))


comparison = df1.compare(df2)
print(comparison)

######################


comp = (
    df[['id', 'p_pred', 'residuals']]
    .merge(
        df_alt[['id', 'p_pred', 'residuals']],
        on='id',
        suffixes=('_df', '_alt')
    )
)

diff_mask = (
    ~(
        (comp['p_pred_df'] == comp['p_pred_alt']) |
        (comp['p_pred_df'].isna() & comp['p_pred_alt'].isna())
    )
    |
    ~(
        (comp['residuals_df'] == comp['residuals_alt']) |
        (comp['residuals_df'].isna() & comp['residuals_alt'].isna())
    )
)

diffs = comp.loc[diff_mask]
diffs['diff_p_pred']=diffs['p_pred_df'] - diffs['p_pred_alt']
diffs['diff_resdiduals']=diffs['residuals_df'] - diffs['residuals_alt']
'''

#df=df_alt

#%% VALUE ADDED
'''
Calculate VA based on residuals
'''

# Calculate average residuals by mediator on their first and second half of cases
df['total_med_cases'] = df.groupby('mediator_id')['residuals'].transform('count') 
df = df.sort_values(['mediator_id', 'med_appt_date', 'id'])
df['temp1'] = df.groupby('mediator_id')['residuals'].transform(
    lambda x: x.iloc[:len(x) // 2].mean())
df['average1'] = df.groupby('mediator_id')['temp1'].transform('mean') 
df['temp2'] = df.groupby('mediator_id')['residuals'].transform(
    lambda x: x.iloc[len(x) // 2:].mean())
df['average2'] = df.groupby('mediator_id')['temp2'].transform('mean')

# Covariance of first and second half residuals, for the whole sample
average1_2 = df.groupby('mediator_id')[['average1', 'average2']].first().dropna()
cov_avgs = np.cov(average1_2['average1'], average1_2['average2'])[0, 1]
cov_avgs_sd = np.sqrt(cov_avgs) # Share
sigma = pd.DataFrame({'sigma': [cov_avgs_sd]})
#sigma.to_csv(f"{su['path']}/Output/VA/sigma_py_{su['date']}.csv", index=False)

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

# Cases: id, p, outcome
df_case = df_case[['id', 'mediator_id', 'p_pred', 'case_outcome_agreement']]
#df_case[['id', 'p_pred', 'case_outcome_agreement']].to_csv(
#    f"{su['path']}/Output/VA/p_pred_py_{su['date']}.csv", index=False)

# VA
df_mediator = df.groupby('mediator_id').agg({'va': 'first'}).reset_index()
#df_mediator.to_csv(f"{su['path']}/Output/VA/VA_py_{su['date']}.csv", index=False)

 # COMPARE WITH STATA
p_stata = pd.read_csv(f"{su['path']}/Output/VA/p_pred_STATA_{su['date']}.csv")
p_both = df_case.merge(p_stata, on='id', how='left')
p_both = p_both[['id', 'p_pred_x', 'p_pred_y']]
p_both = p_both.rename(columns={'p_pred_x': 'p_pred_py', 'p_pred_y': 'p_pred_stata'}) 
p_both['diff'] = p_both['p_pred_py'] - p_both['p_pred_stata']
p_both = p_both.sort_values(['diff'])
#p_both.to_csv(f"{su['path']}/Output/VA/VA_both_{su['date']}.csv", index=False) 
 
va_stata = pd.read_csv(f"{su['path']}/Output/VA/VA_STATA_{su['date']}.csv")
va_both = df_mediator.merge(va_stata, on='mediator_id', how='left')
va_both = va_both[['mediator_id', 'va_x', 'va_y']]
va_both = va_both.rename(columns={'va_x': 'va_py', 'va_y': 'va_stata'}) 
va_both['diff'] = va_both['va_py'] - va_both['va_stata']
va_both = va_both.sort_values(['diff'])
#va_both.to_csv(f"{su['path']}/Output/VA/VA_both_{su['date']}.csv", index=False)


endtime = time.time()

totaltime = endtime - startime

print(totaltime)

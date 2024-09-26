#%% SET UP

# Import libraries
import pandas as pd
import matplotlib
import matplotlib.pyplot as plt

# Import data
posterior = pd.read_csv('Output\Model\posteriors.csv') # Posterior distributions (mean and sd)
va        = pd.read_csv('Output\Model\VA_py_20092024.csv') # Mediator Antoine VA
cases     = pd.read_csv('Data_Clean\cases_cleaned_20092024.csv') # Cases all info
#p_vals    = pd.read_csv('Output\Model\p_pred_predsample_py_20092024.csv') # p estimations from Antoine
p_vals    = pd.read_csv('Output\Model\p_pred_py_18042024.csv') # p estimations from Antoine

# "Mediator" dataframe 
posterior = posterior.rename(columns={"Med_ID": "mediator_id"})
mediator = pd.merge(posterior, va, on='mediator_id')

# "Cases" dataframe 
cases = cases.merge(mediator, on='mediator_id', how='left') # Add mediators data
cases = cases.merge(p_vals, on='id', how='left') # Add p

# Calculate case agreement probability
cases['pred_A'] = cases['va'] + cases['p_pred'] 
cases['pred_F'] = cases['Mean'] + cases['p_pred']

# Calculate prediction error
cases['err_F'] = (cases['pred_F'] - cases['case_outcome_agreement_y'])
cases['err_A'] = (cases['pred_A'] - cases['case_outcome_agreement_y'])

# Calculate MSE
cases['sqerr_F'] = (cases['pred_F'] - cases['case_outcome_agreement_y'])**2
cases['sqerr_A'] = (cases['pred_A'] - cases['case_outcome_agreement_y'])**2

#%% FIGURES

# Scatter: VA (Antoine) vs Posterior mean (Farabi)
fig, ax = plt.subplots()
ax.set_title('Posteriors vs Value Added')
plt.scatter(mediator['Mean'], mediator['va'], s=2, 
            c=mediator['totalcases'], cmap ='coolwarm', 
            norm=matplotlib.colors.LogNorm() )
plt.xlabel('$\mu_i$ mean from the posterior')
plt.ylabel('Value Added')
clb = plt.colorbar()
clb.set_label('Number of cases')
plt.savefig('Output\VA_posterior_scatter.png',dpi=300)

# Histogram: VA (Antoine) & Posterior mean (Farabi)
fig, ax = plt.subplots()
plt.hist(mediator['Mean'], alpha=0.5, bins=20, range=(-0.25,0.25), label='Posterior $\mu$ mean')  
plt.hist(mediator['va'], alpha=0.5, bins=20, range=(-0.25,0.25), label='VA') 
plt.legend(loc='upper right') 
plt.title('VA (Antoine) vs posterior $\mu$ mean (Farabi)') 
plt.savefig('Output\VA_antoine_posterior_farabi.png',dpi=300)

# Histogram: Predictions Antoine & Farabi
fig, ax = plt.subplots()
plt.hist(cases['pred_A'], alpha=0.5, bins=25, range=(-0.25,1.25), label='Predictions Antoine') 
plt.hist(cases['pred_F'], alpha=0.5, bins=25, range=(-0.25,1.25), label='Predictions Farabi') 
plt.legend(loc='upper right') 
plt.title('Predictions') 
plt.savefig('Output\predictions_antoine_farabi.png',dpi=300)

# Histogram: Squared error Antoine & Farabi
fig, ax = plt.subplots()
plt.hist(cases['err_A'],  
         alpha=0.5, bins=28, range=(-1.4,1.4), label='Error Antoine') 
plt.hist(cases['err_F'],
         alpha=0.5, bins=28, range=(-1.4,1.4), label='Error Farabi') 
plt.legend(loc='upper right') 
plt.title('Prediction error distribution') 
plt.savefig('Output\E_dist.png',dpi=300)

# Histogram: MSE Antoine & Farabi
fig, ax = plt.subplots()
plt.hist(cases['sqerr_A'], 
         alpha=0.5, bins=14, range=(0,1.4), label='Squared error Antoine') 
plt.hist(cases['sqerr_F'], 
         alpha=0.5, bins=14, range=(0,1.4), label='Squared error Farabi') 
plt.legend(loc='upper right') 
plt.title('Squared error distribution') 
plt.savefig('Output\SE_dist.png',dpi=300)

#%% PRINT RELEVANT INFO

# Number of predictions outside 0 and 1
print(cases[cases['pred_F'] > 1.0].count())
print(cases[cases['pred_F'] < 0].count())
print(cases[cases['pred_A'] > 1.0].count())
print(cases[cases['pred_A'] < 0].count())

# Mean Squared Error (MSE)
print(cases['sqerr_F'].mean())
print(cases['sqerr_A'].mean())
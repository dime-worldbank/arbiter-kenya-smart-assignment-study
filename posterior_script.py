import numpy as np
import math
import pandas as pd

datapull = "20092024"

def pdf_non_normal(mu, case_history, sigma):
    # evaluates the pdf at mu. Non-normalized
    # case history : a list of cases this mediator took on. each element of the list is a dictionary { 'outcome': 0/1, 'p_value': a float}
    # sigma: the standard deviation of the prior normal distribution
    log_density = (-.5*(mu/sigma)**2) #assuming the mean is 0
    
    for case in case_history:
        #print(case_history[case])
        if case['outcome']==1:
            if case['p_value']+mu>1:
                log_density+= np.log(1)
            elif case['p_value']+mu<0:
                log_density+= np.log(0.00000001)
            else:
                log_density+= np.log(case['p_value']+mu)
        else:
            if 1-case['p_value']-mu>1:
                log_density+= np.log(1)
            elif 1-case['p_value']-mu<0:
                log_density+= np.log(0.00000001)
            else:
                log_density+= np.log(1-case['p_value']-mu)
            
    return np.exp(log_density)



def MCMC(init_theta = 0.05, pdf =pdf_non_normal,iterations=10000,**kwargs):
    #function to sample from pdf_non_normal
    samples=  []
    for iter in range(iterations):
        del_thta = np.random.normal(0,0.3,1)[0]
        new_theta = init_theta + del_thta
        g_new =pdf(mu=new_theta,**kwargs)
        g_old =pdf(mu=init_theta,**kwargs)
        rho = g_new/g_old
       # print(rho,"rho")
        if rho>=1:
            init_theta = new_theta
        else:
            if np.random.binomial(size=1,n=1,p=rho)[0]==1:
               init_theta = new_theta
        samples.append(init_theta)
    return samples

def pdf_summary_stats(**kwargs):
    #calculates the mean and standard deviation of the posterior distribution
    #empirically, as our pdf is not standardized, hence cannot be done analitically 
    samples = MCMC(init_theta = 0, pdf = pdf_non_normal, iterations=10000,**kwargs)
    samples = samples[math.floor(len(samples)*0.8):len(samples)-1]
    emp_avg = np.average(samples)
    emp_sd = np.sqrt(np.var(samples))
    return emp_avg,emp_sd


# write code to analize cases from the provided file cases_cleaned_18042024.csv and p_pred_18042024.csv to extract case history and the case p-values 

cases = pd.read_csv(f'Data_Raw\cases_raw_{datapull}.csv', encoding = 'ISO-8859-1')
p_vals = pd.read_csv(f'Output\Model\p_pred_py_{datapull}.csv')
sigma = pd.read_csv(f'Output\Model\sigma_py_{datapull}.csv')

cases = cases[['id','case_outcome_agreement','mediator_id']]




case_history_by_med = {}

for id in p_vals['id']:
    if pd.isna(cases[cases['id']==id]['mediator_id'].values[0]):
        continue
    med_id = int(cases[cases['id']==id]['mediator_id'].values[0])
    if not (med_id in case_history_by_med):
        case_history_by_med[med_id] = []
    case_history_by_med[med_id].append({'outcome':cases[cases['id']==id]['case_outcome_agreement'].values[0],'p_value':p_vals[p_vals['id']==id]['p_pred'].values[0]})


posterior_stats = {}

for med in case_history_by_med:
    kwargs = {
        'case_history': case_history_by_med[med],
        'sigma': sigma['sigma'].mean()
    }
    emp_avg,emp_sd = pdf_summary_stats(**kwargs)
    posterior_stats[med] = (emp_avg,emp_sd)


# write code to save this in a csv file 
df = pd.DataFrame.from_dict(posterior_stats, orient='index', columns=['Mean', 'SD'])

# Reset the index to have a column for 'Index'
df.reset_index(inplace=True)
df.rename(columns={'index': 'Med_ID'}, inplace=True)

# Display the DataFrame
df.to_csv(f'Output\Model\posteriors_{datapull}.csv', index=False)

# argparse to take input of the names of the files to use 
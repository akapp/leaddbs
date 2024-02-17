import pandas as pd
import numpy as np
import sys
import os
import json
import subprocess
from scipy.optimize import dual_annealing
from Improvement4Protocol import ResultPAM


def store_iteration_results(S_vector,global_score,symptoms_list,estim_Ihat,side_suffix):

    """ maybe make this script into a class """

    # store info about the iteration
    df = pd.DataFrame(
        {
            "weighted_total_score": global_score,
        }
    )

    # stimulation current
    current_data = []
    for i in range(len(S_vector)):
        current_data.append(S_vector[i])
    current_data_array = np.vstack((current_data)).T

    # predicted improvement of symptoms
    for key in symptoms_list:
        df[key] =  estim_Ihat[key]

    for i in range(len(S_vector)):
        df['Contact_' + str(i)] = S_vector[i]  # Lead-DBS notation!

    iter_file = stim_folder + '/NB' + side_suffix + '/optim_iterations.csv'
    df.to_csv(iter_file, mode='a', header=not os.path.exists(iter_file))
def compute_global_score(S_vector, *args):

    stim_folder, side, profile_dict, fixed_symptoms_dict, score_symptom_metric = args

    if side == 0:
        side_suffix = '_0'
    else:
        side_suffix = '_1'

    # we use scaling, but later we will switch to scaling_vector
    with open(os.devnull, 'w') as FNULL:
        subprocess.call(
            proper_python + ' ' + PAM_caller_script + ' ' + neuron_folder + ' ' +
            results_folder + ' ' + timeDomainSolution + ' ' + pathwayParameterFile + ' ' + str(
                S_vector[0]), shell=True)

    # make a prediction
    stim_result = ResultPAM(side, stim_folder)
    stim_result.make_prediction(score_symptom_metric, profile_dict, fixed_symptoms_dict)
    symptoms_list = stim_result.symptom_list
    activation_profile = stim_result.activation_profile

    # put this in a separate function
    # load predicted symptom improvement and weights
    if side == 0:
        estim_Ihat_json = stim_folder + '/NB_0/Estim_symp_improv_rh.json'
    else:
        estim_Ihat_json = stim_folder + '/NB_1/Estim_symp_improv_lh.json'

    with open(estim_Ihat_json, 'r') as fp:
        estim_Ihat = json.load(fp)
    fp.close()

    # load fixed symptom weights
    fp = open(fixed_symptoms_dict)
    symptom_weights = json.load(fp)
    symptom_weights = symptom_weights['fixed_symptom_weights']
    remaining_weights = 1.0
    N_fixed = 0
    # is it iterating only across the correct side?
    for key in symptom_weights:
        remaining_weights = remaining_weights - symptom_weights[key]
        N_fixed += 1

    # compute weight for non-fixed as the equal distribution of what remained
    if len(symptoms_list) != N_fixed:
        rem_weight = remaining_weights / (len(symptoms_list) - N_fixed)
    else:
        rem_weight = 0.0

    # for now, the global score is a simple summation (exactly like in Optim_strategies.py)
    for key in symptoms_list:
        if side == 0 and not ("_rh" in key):
            continue
        elif side == 1 and not ("_lh" in key):
            continue

        if key in symptom_weights:
            global_score = symptom_weights[key] * estim_Ihat[key]
        else:
            global_score = rem_weight * estim_Ihat[key]

    store_iteration_results(S_vector,global_score,symptoms_list,estim_Ihat,side_suffix)

    return global_score

if __name__ == '__main__':

    # called from MATLAB
    PAM_caller_script = sys.argv[1]
    neuron_folder = sys.argv[2]
    optim_settings_file = sys.argv[3]
    proper_python = sys.argv[4]
    results_folder = sys.argv[5]

    with open(optim_settings_file, 'r') as fp:
        optim_settings = json.load(fp)
    fp.close()

    timeDomainSolution = results_folder + '/oss_time_result.h5'
    stim_folder = os.path.dirname(results_folder)
    pathwayParameterFile = stim_folder + "/Allocated_axons_parameters.json"


    args_all = stim_folder, side, profile_dict, fixed_symptoms_dict, score_symptom_metric;

    if os.path.isfile(os.environ['PATIENTDIR'] + '/Best_scaling_yet.csv'):
        initial_scaling = np.genfromtxt(os.environ['PATIENTDIR'] + '/Best_scaling_yet.csv', delimiter=' ')
        res = dual_annealing(compute_global_score,
                             bounds=list(zip(optim_settings['min_bound_per_contact'], optim_settings['max_bound_per_contact'])),
                             args=args_all, x0=initial_scaling, maxfun=optim_settings['num_iterations'], seed=42, visit=2.62,
                             no_local_search=True)
    else:
        res = dual_annealing(compute_global_score,
                             bounds=list(zip(optim_settings['min_bound_per_contact'], optim_settings['max_bound_per_contact'])),
                             args=args_all, maxfun=optim_settings['num_iterations'], seed=42, visit=2.62,
                             no_local_search=True)
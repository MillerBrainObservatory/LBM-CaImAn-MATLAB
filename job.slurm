#!/bin/bash

#SBATCH --job-name=tiffy_lube
#SBATCH --time=0-00:30:00
#SBATCH --nodes=1         
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1        
#SBATCH --mem=64GB       
#SBATCH --output=R-%x.%j.out
#SBATCH --error=R-%x.%j.err

/ru-auth/local/home/ruitsoft/soft/matlab/r2021a/bin/matlab -nodisplay -nojvm -r "job", exit

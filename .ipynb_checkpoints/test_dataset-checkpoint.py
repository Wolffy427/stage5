from datasets import load_dataset

DATASET_SPLIT = "train"
NUM_CALIBRATION_SAMPLES = 256 
dataset = load_dataset('internlm/Condor-SFT-20K', split=f"{DATASET_SPLIT}[:{NUM_CALIBRATION_SAMPLES}]")
dataset = dataset.rename_column("prompt", "text")
print(dataset)
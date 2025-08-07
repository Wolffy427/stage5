from transformers import AutoTokenizer, AutoModelForCausalLM
from datasets import load_dataset
from llmcompressor.modifiers.awq import AWQModifier
from llmcompressor import oneshot
from llmcompressor.utils import dispatch_for_generation
from modelscope import MsDataset

model_dir = '/root/autodl-tmp/models/'
model_id = 'Qwen/Qwen2-7B'

model = AutoModelForCausalLM.from_pretrained(f'{model_dir}/{model_id}')
tokenizer = AutoTokenizer.from_pretrained(f'{model_dir}/{model_id}')
# model = AutoModelForCausalLM.from_pretrained(model_id)
# tokenizer = AutoTokenizer.from_pretrained(model_id)

DATASET_ID = "mit-han-lab/pile-val-backup"
DATASET_SPLIT = "train"
NUM_CALIBRATION_SAMPLES = 256  # 从 256 个样本开始
MAX_SEQUENCE_LENGTH = 512
 

# 加载并预处理数据集
# ds = load_dataset('/root/.cache/modelscope/hub/datasets/'+DATASET_ID, split=f"{DATASET_SPLIT}[:{NUM_CALIBRATION_SAMPLES}]")
ds = load_dataset('internlm/Condor-SFT-20K', split=f"{DATASET_SPLIT}[:{NUM_CALIBRATION_SAMPLES}]")
ds = ds.rename_column("prompt", "text")
ds = ds.shuffle(seed=42)
 

recipe = [
    AWQModifier(ignore=["lm_head"], scheme="W4A16_ASYM", targets=["Linear"]),
]

oneshot(
    model=model,
    dataset=ds,
    recipe=recipe,
    max_seq_length=MAX_SEQUENCE_LENGTH,
    num_calibration_samples=NUM_CALIBRATION_SAMPLES,
)

# 简单生成测试
print("========== 样本生成 ==============")
dispatch_for_generation(model)  # 确保模型在正确的设备上
input_ids = tokenizer("Hello my name is", return_tensors="pt").input_ids.to("cuda")
output = model.generate(input_ids, max_new_tokens=20)
print(tokenizer.decode(output[0]))
print("===================================")

# 使用压缩张量格式保存
SAVE_DIR = model_dir + model_id.rstrip("/").split("/")[-1] + "-awq-w4a16"
model.save_pretrained(SAVE_DIR, save_compressed=True)
tokenizer.save_pretrained(SAVE_DIR)
import json

with open('qf_test_log_double.txt', 'r') as f:
    lines = f.readlines()
max_psnr = -1000
max_line = None
for line in lines:
    data = json.loads(line)
    if data['psnr'] > max_psnr:
        max_psnr = data['psnr']
        max_line = data

print("Parameters for maximum PSNR:")
print(max_line)
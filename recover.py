import json
import re

log_path = r'C:\Users\moham\.gemini\antigravity\brain\d155c19c-9a29-4c2d-b2c3-bb3217979115\.system_generated\logs\transcript.jsonl'

best_content = ''
max_len = 0

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            if 'content' in data:
                content = data['content']
                if 'class CoachPlayerDetailScreen extends ConsumerStatefulWidget' in content:
                    matches = re.findall(r'<file\s+path=".*?coach_player_detail_screen\.dart">([\s\S]*?)</file>', content)
                    for m in matches:
                        if len(m) > max_len:
                            max_len = len(m)
                            best_content = m
        except:
            pass

if best_content:
    with open('recovered_file.dart', 'w', encoding='utf-8') as f:
        f.write(best_content)
    print(f'Recovered file length: {len(best_content)}')
else:
    print('Could not find file in transcript.')

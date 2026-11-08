import json
import re
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
text = (root / 'lib' / 'src' / 'animal_shapes.dart').read_text(encoding='utf-8')

# Find kAnimalArt block
start_idx = text.find('const Map<DitherAnimalType, AnimalArt> kAnimalArt = {')
if start_idx == -1:
    print('kAnimalArt not found')
    exit(1)

body = text[start_idx:]
# Split by DitherAnimalType.
parts = body.split('DitherAnimalType.')

result = {}
for p in parts[1:]:
    # First token is the animal name
    colon_idx = p.find(':')
    if colon_idx == -1:
        continue
    animal_name = p[:colon_idx].strip()
    
    # Layers
    layers = []
    layer_matches = re.findall(r"ShapeLayer\s*\(\s*'([^']+)'\s*,\s*([0-9.]+)\s*\)", p)
    for path, density in layer_matches:
        if animal_name == 'peacock' and 'M1 54 a49 44' in path:
            continue  # Skip full-canvas 0.5 backdrop so peacock renders in clean light mode
        layers.append([path, float(density)])
        
    # Eyes & cheeks are in [EyeSpec(x,y,r), ...]
    # There are two lists of EyeSpec: first is eyes, second is cheeks
    # Let's find [EyeSpec...] blocks
    eye_blocks = re.findall(r"\[(EyeSpec\([^]]+\))\]", p)
    eyes = []
    cheeks = []
    if len(eye_blocks) >= 1:
        for ex, ey, er in re.findall(r"EyeSpec\s*\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)", eye_blocks[0]):
            eyes.append([float(ex), float(ey), float(er)])
    if len(eye_blocks) >= 2:
        for cx, cy, cr in re.findall(r"EyeSpec\s*\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)", eye_blocks[1]):
            cheeks.append([float(cx), float(cy), float(cr)])
            
    # Details
    details = []
    for dk, dp, dw in re.findall(r"DetailSpec\s*\(\s*([0-9]+)\s*,\s*'([^']+)'\s*,\s*([0-9.]+)", p):
        details.append([int(dk), dp, float(dw)])
        
    result[animal_name] = {
        'layers': layers,
        'eyes': eyes,
        'cheeks': cheeks,
        'details': details
    }

print(f'Successfully parsed {len(result)} animals.')
out_path = root / 'website' / 'data' / 'animal_shapes.json'
out_path.write_text(json.dumps(result, separators=(',', ':')), encoding='utf-8')
print(f'Wrote {out_path.stat().st_size} bytes to {out_path}')

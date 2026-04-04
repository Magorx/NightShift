# Blender Pipeline

## Tools

### `inspect_model.py` -- Model inspection screenshots
Takes 4 screenshots of a `.glb` model from different angles for quick visual assessment.

```bash
BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"

# Basic -- 4 PNGs saved to <model_dir>/inspect/
$BLENDER --background --python tools/blender/inspect_model.py -- path/to/model.glb

# Custom resolution and zoom
$BLENDER --background --python tools/blender/inspect_model.py -- model.glb -w 1024 --ortho-scale 3.0

# Override random cameras with specific azimuth/elevation (degrees)
$BLENDER --background --python tools/blender/inspect_model.py -- model.glb --cam3 120 20 --cam4 240 10

# Reproducible random angles
$BLENDER --background --python tools/blender/inspect_model.py -- model.glb --seed 42
```

**Cameras:**
- 2 fixed: standard isometric (az=45, el=54.7) and opposite (az=225, el=54.7)
- 2 random: randomized azimuth 0-360, elevation 15-65 (override with `--cam3`/`--cam4`)

**Features:**
- Auto-fit zoom from bounding box (override with `--ortho-scale`)
- 3-point lighting (key + fill + rim)
- 16x AA samples for readable inspection renders
- Track-to constraint keeps cameras aimed at model center

**Use after every model build** to verify the result looks correct before committing.

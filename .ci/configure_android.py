"""Configure Godot's user-local SDK paths for prebuilt APK export."""
import base64
import os
from pathlib import Path
sdk = Path(os.environ['ANDROID_HOME'])
java = Path(os.environ['JAVA_HOME'])
assert (sdk / 'platform-tools/adb').is_file()
assert (java / 'bin/java').is_file()
settings = Path.home() / '.config/godot/editor_settings-4.6.tres'
content = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for name, value in [('export/android/android_sdk_path', sdk), ('export/android/java_sdk_path', java)]:
    lines = [line for line in content.splitlines() if not line.startswith(name+' =')]
    content = '\n'.join(lines)+f'\n{name} = "{value.as_posix()}"\n'
settings.parent.mkdir(parents=True, exist_ok=True)
settings.write_text(content)
key = Path('builds/signing/development.keystore')
key.parent.mkdir(parents=True, exist_ok=True)
key.write_bytes(base64.b64decode(Path('.ci/android-development-key.b64').read_text()))

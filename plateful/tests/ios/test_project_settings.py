"""Check the shipping project's optional Google callback without using account credentials."""
import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def check_project_settings():
    ios = Path(__file__).resolve().parents[2] / "apps/ios"
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "Along").mkdir()
        generator = root / "generate_project.py"
        shutil.copyfile(ios / generator.name, generator)
        shutil.copyfile(ios / "Along/BuildInfo.plist", root / "Along/BuildInfo.plist")
        project = root / "Along.xcodeproj/project.pbxproj"

        # A configured build registers a typed URL-scheme array while retaining its billing settings.
        fixture = root / "Along/GoogleService-Info.plist"
        scheme = "com.googleusercontent.apps.0123-fixture"
        fixture.write_bytes(plistlib.dumps({"REVERSED_CLIENT_ID": scheme}))
        subprocess.run([sys.executable, generator], check=True, stdout=subprocess.DEVNULL)
        assert "INFOPLIST_FILE = .build/Along-Google-Info.plist;" in project.read_text()
        info = plistlib.loads((root / ".build/Along-Google-Info.plist").read_bytes())
        assert info["CFBundleURLTypes"][0]["CFBundleURLSchemes"] == [scheme]
        assert info["ALONG_BILLING_ANNUAL_PRODUCT_ID"] == "$(ALONG_BILLING_ANNUAL_PRODUCT_ID)"

        # Removing the private configuration switches both build configurations back to the public plist.
        fixture.unlink()
        subprocess.run([sys.executable, generator], check=True, stdout=subprocess.DEVNULL)
        assert project.read_text().count("INFOPLIST_FILE = Along/BuildInfo.plist;") == 2
        assert "GoogleService-Info.plist" not in project.read_text()
        print("Configured and unconfigured iOS project settings passed")


if __name__ == "__main__":
    check_project_settings()

On a brand new instance

1. Get the script (from your GitHub repo):
   ```bash
   curl -O https://raw.githubusercontent.com/your-username/rclone-setup/main/rclone-setup.sh
   ```
2. Make it executable:
   ```bash
   chmod +x rclone-setup.sh
   ```
3. Run the setup:
   ```bash
   ./rclone-setup.sh
   ```
   This will:
   · Install wget, unzip, bash, nano, curl (if missing).
   · Install rclone (if missing).
   · Create ~/.config/rclone/rclone.conf with placeholders.
   · Create upload.sh in the current directory.
4. Edit the config with your real IA keys:
   ```bash
   nano ~/.config/rclone/rclone.conf
   ```
5. Upload any file:
   ```bash
   ./upload.sh "https://example.com/file.mp4" "ia2:/bucket/path/file.mp4"
   ```

---

Or even shorter – one‑liner setup

If you want to skip the separate download+chmod+run steps:

```bash
bash <(curl -s https://raw.githubusercontent.com/your-username/rclone-setup/main/rclone-setup.sh)
```

This runs the setup immediately – still need to edit the config afterwards, of course.

---

Important: upload.sh uses wget + rclone rcat

The upload script streams directly from the URL to IA – no local file stored. It shows progress and returns clear success/failure messages.

---

You’re ready to go. 🚀

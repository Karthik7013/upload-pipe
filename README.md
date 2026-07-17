# Using curl
curl -O https://raw.githubusercontent.com/Karthik7013/upload-pipe/main/rclone-setup.sh

chmod +x rclone-setup.sh
./rclone-setup.sh

# Or in a single line
bash <(curl -s https://your-hosting-url/rclone-setup.sh)

nano ~/.config/rclone/rclone.conf

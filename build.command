#!/bin/bash
# Bấm đúp file này trên Mac để tạo app (tương đương build.bat bên Windows)
cd "$(dirname "$0")"
./build.sh && open dist
echo; read -n 1 -s -r -p "Bấm phím bất kỳ để đóng..."

#!/bin/bash
# @Author: clsty <celestial.y@outlook.com>
# @Title: arCNiso makeiso: auto make iso file.
# @URL: https://github.com/clsty/arCNiso
# @License: GNU GPL v3.0 License

# 初始设定
set -e # 遇错直接退出
function try { "$@" || sleep 0; }

# 时间测量开始
echo "开始构建。"
TIME1=$(date +%Y%m%d-%H:%M:%S)
TIME1_s=$(date +%s)

# 位置与权限校正
cd $(dirname $0)
try sudo umount ./TMP/x86_64/airootfs/*
sudo chown -R $(whoami):$(whoami) .

# 家目录就位
rsync -av --delete ./homebase/public/ ./airootfs/etc/skel/
rsync -av --delete ./homebase/public/ ./airootfs/root/
rsync -av ./homebase/skel/ ./airootfs/etc/skel/
rsync -av ./homebase/root/ ./airootfs/root/
# TODO: pandoc 目前无法将org文件中的 "#+begin/end_quote" 中包含的 "=...=" 或 "~...~" 等行内代码块正确地转换出来，无论是输出到md还是html都如此。
# 当前只能避免在 "#+begin/end_quote" 中使用 "=...=" 或 "~...~" 等行内代码块。
pandoc docs/README.org \
	-N \
	--output=./airootfs/etc/skel/README.html \
	--metadata title="arCNiso 自述文档（pandoc 离线版）" \
	--metadata date="$(date +%x)" \
	--to=html5 \
	--css=docs/github.css \
	--highlight-style=haddock \
	--standalone
pandoc docs/Installation_hint.org \
	-N \
	--output=./airootfs/etc/skel/Installation_hint.html \
	--metadata title="Arch Linux 安装提示（pandoc 离线版）" \
	--metadata date="$(date +%x)" \
	--to=html5 \
	--css=docs/github.css \
	--highlight-style=haddock \
	--embed-resources \
	--standalone
#lynx -dump -nolist "https://wiki.archlinux.org/title/Installation_Guide?action=render" >> ./airootfs/etc/skel/Installation_guide.txt
#curl "https://wiki.archlinuxcn.org/wiki/Installation_Guide?action=render" -o ./airootfs/etc/skel/Installation_guide.html
pandoc "https://wiki.archlinuxcn.org/wiki/Installation_Guide?action=render" \
	-N -f html \
	--output ./airootfs/etc/skel/Installation_guide.html \
	--metadata title="安装指南（来自 Arch Linux 中文维基，pandoc 离线版）" \
	--metadata date="$(date +%x)" \
	--to=html5 \
	--css=docs/github.css \
	--highlight-style=haddock \
	--embed-resources \
	--standalone

# 本地软件仓库与源就位
# 以下通过软链接到 /tmp 下，获得不含变量的路径（因为 pacman.conf 似乎不支持含变量的路径），以供后续使用。
mkdir -p /tmp/arCNiso
touch /tmp/arCNiso/touched
rm /tmp/arCNiso/* # 注意这里应当只有软链接及 touched
ln -sf $(pwd)/aur/pkgs /tmp/arCNiso/aur
ln -sf $(pwd)/pacman.d /tmp/arCNiso/pacman.d

# 准备相关密钥
# https://wiki.archlinux.org/title/Archiso#Adding_repositories_to_the_image
# https://github.com/archlinuxcn/archlinuxcn-keyring
if [ -f ./githubrawprefix ]; then
	githubrawprefix="$(cat ./githubrawprefix)"
else
	githubrawprefix="https://raw.githubusercontent.com/"
fi
for i in "archlinuxcn.gpg" "archlinuxcn-trusted" "archlinuxcn-revoked"; do
	curl -o ./airootfs/usr/share/pacman/keyrings/"${i}" "${githubrawprefix}"archlinuxcn/archlinuxcn-keyring/master/"${i}"
done
# 注：以上与添加 archlinuxcn-keyring 到包名列表是互斥的（二选一）

# 构建
mkdir -p OUT TMP
sudo rm -rf OUT TMP
if [ -f ./patchedmkarchiso/mkarchiso ]; then
	echo "已找到 patchedmkarchiso 目录下的 mkarchiso，将使用修改后的 mkarchiso。"
	cp ./patchedmkarchiso/db.{cer,key,crt} ./
	sudo ./patchedmkarchiso/mkarchiso -v -w TMP -o OUT ./
else
	echo "未找到 patchedmkarchiso 目录下的 mkarchiso，将使用原版 mkarchiso。"
	sudo mkarchiso -v -w TMP -o OUT ./
fi
sudo rm -rf TMP
sudo chown -R $(whoami):$(whoami) ./OUT
mv $(find OUT -name "*.iso") OUT/arCNiso.iso

# 清理临时文件（夹）
try rm -rf ./airootfs/etc/skel
try rm -rf ./airootfs/root
try rm ./db.{cer,key,crt}

# 输出信息
export name=$(basename $(find OUT -name "*.iso"))
export size=$(du -a -B MB OUT/*.iso | cut -f1 -d"	")
export sha256sum=$(sha256sum OUT/*.iso | cut -f1 -d" ")

echo "文件名：${name}
大小：${size}
sha256sum：${sha256sum}" >result.log
cat result.log

echo "文件名：${name}

大小：${size}

sha256sum：${sha256sum}" >result.md

# 时间测量结束
TIME2=$(date +%Y%m%d-%H:%M:%S)
TIME2_s=$(date +%s)
TIMEpass=$(($TIME2_s - $TIME1_s))
echo "构建结束。"
echo "开始于 $TIME1 -- 经过 $TIMEpass 秒 --> 结束于 $TIME2"

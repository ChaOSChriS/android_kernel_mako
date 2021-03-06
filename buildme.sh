#!/bin/bash
#sourcedir
SD="$(pwd)"
OUTDIR="$SD/out/$CODENAME/"
CODENAME="mako"
DEFCONFIG="mako_config"
NRJOBS=$(( $(nproc) * 2 ))
#TOOLCHAIN="$SD/ChaOS/toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.9.1-2014.07/bin"
TOOLCHAIN="$SD/ChaOS/toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.8.4-2014.08/bin"

if [ -z "$1" ]; then
  VERSION="KTU"
 echo "[BUILD]: WARNING: Not called with Version(KTU/KTUO), defaulting to $VERSION!";
 echo "[BUILD]: If this is not what you want, call this script with the Version(KTU/KTUO).";
  echo "[BUILD]: Current Version: $VERSION";
else
  VERSION=$1;
  echo "[BUILD]: Current Version: $VERSION";
fi

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/arm-cortex_a15-linux-gnueabihf-
echo "[BUILD]: Used Toolchain:  ";
$TOOLCHAIN/arm-cortex_a15-linux-gnueabihf-gcc --version;

#saving new rev
REV=$(git log --pretty=format:'%h' -n 1)
echo "[BUILD]: Saved current hash as revision: $REV...";
#date of build
DATE=$(date +%Y%m%d)
DATEE=$(date +%H%M%S)
echo "[BUILD]: Start of build: $DATE...";

#build the kernel
echo "[BUILD]: Cleaning kernel (make mrproper)...";
make mrproper
#make $DEFCONFIG
if [ "$VERSION" = "KTU" ]; then
cp $SD/arch/arm/configs/mako_config $SD/.config
echo "[BUILD]: Changing CONFIG_LOCALVERSION to: -MiRaGe_any...";
sed -i "/CONFIG_LOCALVERSION=\"/c\CONFIG_LOCALVERSION=\"-MiRaGe_any\"" .config
OUTDIR="$SD/out/$CODENAME/standard/";
elif [ "$VERSION" = "KTUO"  ]; then
cp $SD/arch/arm/configs/mako_oc_config $SD/.config
echo "[BUILD]: Changing CONFIG_LOCALVERSION to: -MiRaGe_any_OC...";
sed -i "/CONFIG_LOCALVERSION=\"/c\CONFIG_LOCALVERSION=\"-MiRaGe_any_OC\"" .config
OUTDIR="$SD/out/$CODENAME/overclocked/";
else
echo "[BUILD]:  You set a wrong Version! You choose: $VERSION instead of KTU or KTUO ";
echo "[BUILD]:  Stop building... ";
read
echo "[BUILD]:  Press a key to exit ";
exit
fi




###CCACHE CONFIGURATION STARTS HERE, DO NOT MESS WITH IT!!!
TOOLCHAIN_CCACHE="$TOOLCHAIN/../bin-ccache"
gototoolchain() {
  echo "[BUILD]: Changing directory to $TOOLCHAIN/../ ...";
  cd $TOOLCHAIN/../
}

gotocctoolchain() {
  echo "[BUILD]: Changing directory to $TOOLCHAIN_CCACHE...";
  cd $TOOLCHAIN_CCACHE
}

#check ccache configuration
#if not configured, do that now.
if [ ! -d "$TOOLCHAIN_CCACHE" ]; then
    echo "[BUILD]: CCACHE: not configured! Doing it now...";
    gototoolchain
    mkdir bin-ccache
    gotocctoolchain
    ln -s $(which ccache) "$CROSSCC""gcc"
    ln -s $(which ccache) "$CROSSCC""g++"
    ln -s $(which ccache) "$CROSSCC""cpp"
    ln -s $(which ccache) "$CROSSCC""c++"
    gototoolchain
    chmod -R 777 bin-ccache
    echo "[BUILD]: CCACHE: Done...";
fi
export CCACHE_DIR=$USERCCDIR
cd $SD
###CCACHE CONFIGURATION ENDS HERE, DO NOT MESS WITH IT!!!

echo "[BUILD]: Bulding the kernel...";
time make zImage  -j$NRJOBS || { return 1; }

 if [ -f "$SD/arch/arm/boot/zImage" ];
    then
        echo "[BUILD]: Done with kernel!...";
    else
        echo "[BUILD]: Error"
        exit 0
    fi

echo "[BUILD]: creating output folders";

mkdir -p $SD/out/$CODENAME
mkdir -p $SD/out/$CODENAME/kernel
#mkdir -p $SD/out/$CODENAME/modules
mkdir -p $OUTDIR
#mkdir -p $SD/out/$CODENAME/META-INF/com/google/android

echo "[BUILD]: moving kernel to output";

mv $SD/arch/arm/boot/zImage $SD/out/$CODENAME/kernel/zImage
#find $SD/ -name \*.ko -exec cp '{}' $SD/out/$CODENAME/system/lib/modules/ ';'

echo "[BUILD]: Cleaning out directory...";
cd $SD/out/$CODENAME/
find $SD/out/$CODENAME/* -maxdepth 0 ! -name '*.zip' ! -name '*.txt' ! -name '*.md5' ! -name '*.sha1' ! -name kernel ! -name modules ! -name out ! -name standard ! -name overclocked -exec rm -rf '{}' ';'


echo "[BUILD]: copy flashing tools to output";

cp -R $SD/ChaOS/tools/* $SD/out/$CODENAME
cd $SD/out/$CODENAME

 #create zip and clean folder
    echo "[BUILD]: Creating zip: MiRaGe_any_"$CODENAME"_"$VERSION"_"$DATE".zip ...";
    zip -r $OUTDIR/MiRaGe_any_"$CODENAME"_"$VERSION"_"$DATE"_"$DATEE".zip . -x "/standard*" "/overclocked*" "*.zip" "*.sha1" "*.md5"
echo "[BUILD]: Creating changelog: MiRaGe_any_"$CODENAME"_"$VERSION"_"$DATE".txt ...";
cd $SD
git log --pretty=format:'%h (%an) : %s' --graph $REV^..HEAD > $OUTDIR/MiRaGe_any_"$CODENAME"_"$VERSION"_"$DATE"_"$DATEE".txt
    echo "[BUILD]: Done!...";


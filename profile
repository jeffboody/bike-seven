# App
export APP=BikeSeven

# Update SDK to point to the Android SDK
SDK=/home/jeffboody/android/android-sdk

#-- DON'T CHANGE BELOW LINE --

export PATH=$SDK/tools:$SDK/platform-tools:$PATH
echo "sdk.dir=$SDK" > project/local.properties

export TOP=`pwd`
alias croot='cd $TOP'

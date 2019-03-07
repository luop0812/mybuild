#!/bin/bash 

# error code
success=0
cmd_faild=1
global_not_found=2
local_not_found=3
method_not_found=4
params_error=5
preprocess_error=6
postprocess_error=7
exension_error=8
missing_arg_get_ext=9
existing_software=10
unpack_check_failed=11

##### functions #####

get_ext() {
    if [ $1"x" == "x" ]; then
        echo "Missing parameter to get_ext()"
        exit $missing_arg_get_ext
    fi

    str=$1

    echo $str | grep -e "\.tar\.gz$"  > /dev/null
    if [ $? -eq 0 ]; then
        echo "tar.gz"
        return 0
    fi
    echo $str | grep -e "\.tgz$" > /dev/null
    if [ $? -eq 0 ]; then
        echo "tgz"
        return 0
    fi
    echo $str | grep -e "\.tar$" > /dev/null
    if [ $? -eq 0 ]; then
        echo "tar"
        return 0
    fi
    echo $str | grep -e "\.gz$" > /dev/null
    if [ $? -eq 0 ]; then
        echo "gz"
        return 0
    fi

    echo "nomatch"
    return 1
}

if [ $# != 1 ]; then
    echo "Usage: $0 pkg_name"
    exit $params_error
fi

# tools for convinience
# source ./tools.sh

# _url, _download, _build, _cmd
# are imported from global and local package config file

_flavor=${COMPILER:-intel}

_dir=$(dirname $0)
if [ ! -f ${_dir}/global-${_flavor}.cfg ]; then
    echo "${_dir}/global-${_flavor}.cfg not found."
    exit $global_not_found
fi
. ${_dir}/global-${_flavor}.cfg

echo "###############################"
echo "Building $1"
echo "###############################"

_cfg=$1".cfg"
if [ ! -f ${_dir}/${_cfg} ]; then
    echo "${_dir}/${_cfg} doesn't exist."
    exit $local_not_found
fi
. ${_dir}/${_cfg}

if [ ! -d ${_download} ]; then
    mkdir -p ${_download}
fi

if [ ! -d ${_build} ]; then
   mkdir -p ${_build}
fi

if [ ${_method} == 'WGET' ]; then
    cd ${_download}
    [ "x${_fname}" == "x" ] && _fname=$(basename ${_url})
    echo "filename="${_fname}

    [ -f ${_fname} ] || wget -O ${_fname} ${_url}
    cd ${_build}

    # check the file extension to determin how to unpack the software
    ext=$(get_ext ${_fname})
    case "$ext" in
    "tar.gz" | "tgz")
        unpack_test="tar tzf ${_download}/${_fname} 2>/dev/null |head -1 |cut -d/ -f1"
        unpack="tar xzvf ${_download}/${_fname}"
        ;;
    "tar")
        unpack_test="tar tf ${_download}/${_fname} 2>/dev/null |head -1 |cut -d/ -f1"
        unpack="tar xvf ${_download}/${_fname}"
        ;;
    "gz")
        unpack_test=""
        unpack=""
        ;;
    "nomatch")
        echo "Extension cannot be recognized."
        exit $extension_error
    esac

    _dname=$(eval "$unpack_test")   # redirect warning messages to /dev/null
    if [ $? != 0 ]; then
        echo "cannot check the file status."
        exit $unpack_check_failed
    fi 
      
    echo "dirname="${_dname}
    [ -d ${_dname} ] || eval "$unpack"
    cd ${_build}/${_dname}

elif [ ${_method} == "GIT" ]; then
    cd ${_build}
    git clone ${_url}
    _dname=$(basename ${_url})
    cd ${_dname}
else
    echo "Method of downloading the package is not supported"
    exit $method_not_found
fi

## preprocessing
eval "${_preprocess}"
if [ $? != 0 ]; then
    echo "Preprocessing failed."
    exit $preprocess_error
fi

eval "${_buildcmd}"
if [ $? != 0 ]; then
    echo "Error: please check the log file."
    exit $cmd_faild
fi

eval "${_postprocess}"
if [ $? != 0 ]; then
    echo "Postprocessing failed."
    exit $postprocess_error
fi

exit $success


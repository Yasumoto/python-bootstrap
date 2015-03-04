set -eux

INSTALL_ROOT=$HOME/Python
CPY=$INSTALL_ROOT/CPython
PYPY=$INSTALL_ROOT/PyPy

SANDBOX=$(mktemp -d /tmp/python.XXXXXX)

CURL='wget --no-check-certificate'

mkdir -p $INSTALL_ROOT

PYTHON_2_6=2.6.9
PYTHON_2_7=2.7.9
PYTHON_3_3=3.3.6
PYTHON_3_4=3.4.3
PY_PY=2.5.0
SETUPTOOLS=12.0.5
PIP=6.0.8

pushd $SANDBOX

  wget http://zlib.net/zlib-1.2.8.tar.gz
  tar xzf zlib-1.2.8.tar.gz
  pushd zlib-1.2.8
    ./configure --static --prefix=$SANDBOX/zlib
    make -j3
    make install
  popd
  rm -rf ./zlib-1.2.8.tar.gz ./zlib-1.2.8

  wget https://www.openssl.org/source/openssl-1.0.2.tar.gz
  tar xzf ./openssl-1.0.2.tar.gz
  pushd openssl-1.0.2
    # This is some black magic, and I cannot confirm this will
    # work on anything other than OS X 10.10
    OPENSSL_KERNEL_BITS=32
    if [ -n "$(uname -a | grep x86_64)" ]; then
      OPENSSL_KERNEL_BITS=64
    fi
    KERNEL_BITS=${OPENSSL_KERNEL_BITS} LDFLAGS="-L${SANDBOX}/zlib/lib" CFLAGS="-I${SANDBOX}/zlib/include" \
      ./config -L${SANDBOX}/zlib/lib -I${SANDBOX}/zlib/include no-shared zlib --openssldir=${SANDBOX}/openssl
    # I couldn't get this to work with -j > 1
    make
    make install
  popd
  rm -rf ./openssl-1.0.2.tar.gz ./openssl-1.0.2

  wget ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz
  tar xzf readline-6.2.tar.gz
  pushd readline-6.2
    ./configure --disable-shared --enable-static --prefix=${SANDBOX}/readline
    make -j3
    make install
  popd
  rm -rf readline-6.2.tar.gz readline-6.2

  # install all major cpython interpreter versions
  for version in $PYTHON_2_6 $PYTHON_2_7 $PYTHON_3_3 $PYTHON_3_4; do
    $CURL http://python.org/ftp/python/$version/Python-$version.tgz
    tar xzf Python-$version.tgz
    pushd Python-$version
      LDFLAGS="-L${SANDBOX}/readline/lib -L${SANDBOX}/zlib/lib -L${SANDBOX}/openssl/lib" \
          CFLAGS="-I${SANDBOX}/readline/include -I${SANDBOX}/zlib/include -I${SANDBOX}/openssl/include" \
          ./configure --prefix=$INSTALL_ROOT/CPython-$version && make -j5 && make install
    popd
    rm -f Python-$version.tgz
  done

  # install pypy
  for pypy_version in $PY_PY-osx64; do
    pushd $INSTALL_ROOT
      $CURL https://bitbucket.org/pypy/pypy/downloads/pypy-$pypy_version.tar.bz2
      bzip2 -cd pypy-$pypy_version.tar.bz2 | tar -xf -
      rm -f pypy-$pypy_version.tar.bz2
      mv pypy-$pypy_version PyPy-$PY_PY
    popd
  done

  $CURL https://pypi.python.org/packages/source/s/setuptools/setuptools-$SETUPTOOLS.tar.gz
  $CURL http://pypi.python.org/packages/source/p/pip/pip-$PIP.tar.gz

  for interpreter in $CPY-$PYTHON_2_6/bin/python2.6 \
                     $CPY-$PYTHON_2_7/bin/python2.7 \
                     $CPY-$PYTHON_3_3/bin/python3.3 \
                     $CPY-$PYTHON_3_4/bin/python3.4 \
                     $PYPY-$PY_PY/bin/pypy; do
    # install distribute && pip
    for base in setuptools-$SETUPTOOLS pip-$PIP; do
      tar xzf $base.tar.gz
      pushd $base
        $interpreter setup.py install
      popd
      rm -rf $base
    done
  done

  rm -f setuptools-$SETUPTOOLS.tar.gz pip-$PIP.tar.gz
popd

METAPATH='$PATH'
for path in $(ls $INSTALL_ROOT | sort -r); do
  METAPATH=$INSTALL_ROOT/$path/bin:$METAPATH
done

echo Add the following line to the end of your .bashrc:
echo PATH=$METAPATH

rm -rf $SANDBOX


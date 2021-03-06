config()
{
rm -rf /home/temuppar/work/pg/install.$1
cd contrib
make clean
cd ..
make clean
./configure CFLAGS='-DAZURE_ORCAS_BREADTH' --without-zlib --with-openssl --prefix=/home/temuppar/work/pg/install.$1 --enable-debug --enable-cassert --enable-tap-tests
}

build()
{
make -j8 && make install && make -C ./contrib install
}
if [ $# -ne 1 ]
then
        echo "Please pass rel version"
        exit
fi

export PATH="/home/temuppar/work/pg/install.$1/bin:$PATH"
echo "Enter choice 1)Config 2)Build "
read opt
case $opt in

        1) config $1;
                ;;
        2) build;
                ;;
esac

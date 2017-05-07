FROM centos:7
MAINTAINER Yanfu Zhou <yanfu.zhou@outlook.com>
LABEL Vendor="TBD" \
      Version=1.0.0

# Set environmantal varibles
ENV WORKER_NUM 4
ENV PYTHON_VERSION 2.7.13
ENV CURL_VERSION 7.43.0
ENV APP_NAME GRASS-WPS
ENV APP_START_SCRIPT grassapp

# Expose port
ENV PORT 4000

# Install Python
RUN yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel expat-devel wget libcurl-devel && \
	yum -y install epel-release && \
	yum -y update && \
	yum -y groupinstall "Development Tools" && \
	wget http://python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
	tar xf Python-${PYTHON_VERSION}.tar.xz && \
	cd Python-${PYTHON_VERSION} && \
	./configure --prefix=/usr/local --enable-unicode=ucs4 --enable-shared LDFLAGS="-Wl,-rpath /usr/local/lib" && \
	make && make altinstall && \
	strip /usr/local/lib/libpython2.7.so.1.0 && \
	wget https://bootstrap.pypa.io/get-pip.py && \
	python2.7 get-pip.py && \
	pip2.7 install --no-cache-dir virtualenv && \
	mkdir ~/.pip && \
	echo "[list]" >> ~/.pip/pip.conf && \
	echo "format=columns" >> ~/.pip/pip.conf && \
	cd ../ && \
	rm -f Python-${PYTHON_VERSION}.tar.xz && \
	rm -rf Python-${PYTHON_VERSION}

# Install GRASS
RUN wget -O /etc/yum.repos.d/grass72.repo https://copr.fedoraproject.org/coprs/neteler/grass72/repo/epel-7/neteler-grass72-epel-7.repo && \
	yum -y update && \
	yum install -y grass grass-libs grass-devel liblas liblas-devel

# Deploy GRASS-WPS
COPY ${APP_NAME}.tar.gz /${APP_NAME}.tar.gz
RUN tar -xzf ${APP_NAME}.tar.gz && \
	rm ${APP_NAME}.tar.gz && \
	mv ${APP_NAME} /src

# Setup environment
WORKDIR /src
ADD requirements.txt .
RUN virtualenv -p /usr/local/bin/python2.7 venv && \
	source venv/bin/activate && \
	pip install --no-cache-dir -r requirements.txt && \
	pip install --no-cache-dir pycurl==${CURL_VERSION} --global-option="--with-nss" && \
	pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U && \
	echo "#!/bin/bash" >> startup.sh && \
	echo "source grass72.sh" >> startup.sh && \
	echo "source venv/bin/activate" >> startup.sh && \
	echo "gunicorn -w ${WORKER_NUM} -k gevent -b 0.0.0.0:${PORT} ${APP_START_SCRIPT}:app" >> startup.sh && \
	chmod +x startup.sh  && \
	yum -y groupremove "Development Tools" && \
	yum -y remove wget && \
	yum clean all

EXPOSE ${PORT}

CMD ["./startup.sh"]
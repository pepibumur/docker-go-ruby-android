FROM openjdk:8-jdk-slim

### ANDROID
### https://github.com/CircleCI-Public/example-images/blob/master/android/Dockerfile
ADD https://raw.githubusercontent.com/circleci/circleci-images/master/android/bin/circle-android /bin/circle-android
RUN chmod +rx /bin/circle-android
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90circleci \
	&& echo 'DPkg::Options "--force-confnew";' >> /etc/apt/apt.conf.d/90circleci
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& mkdir -p /usr/share/man/man1 \
	&& apt-get install -y \
	git mercurial xvfb \
	locales sudo openssh-client ca-certificates tar gzip parallel \
	net-tools netcat unzip zip bzip2 gnupg curl wget
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8
RUN JQ_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/jq-latest" \
	&& curl --silent --show-error --location --fail --retry 3 --output /usr/bin/jq $JQ_URL \
	&& chmod +x /usr/bin/jq \
	&& jq --version
RUN set -ex \
	&& export DOCKER_VERSION=$(curl --silent --fail --retry 3 https://download.docker.com/linux/static/stable/x86_64/ | grep -o -e 'docker-[.0-9]*-ce\.tgz' | sort -r | head -n 1) \
	&& DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/${DOCKER_VERSION}" \
	&& echo Docker URL: $DOCKER_URL \
	&& curl --silent --show-error --location --fail --retry 3 --output /tmp/docker.tgz "${DOCKER_URL}" \
	&& ls -lha /tmp/docker.tgz \
	&& tar -xz -C /tmp -f /tmp/docker.tgz \
	&& mv /tmp/docker/* /usr/bin \
	&& rm -rf /tmp/docker /tmp/docker.tgz \
	&& which docker \
	&& (docker version || true)
RUN COMPOSE_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/docker-compose-latest" \
	&& curl --silent --show-error --location --fail --retry 3 --output /usr/bin/docker-compose $COMPOSE_URL \
	&& chmod +x /usr/bin/docker-compose \
	&& docker-compose version
RUN DOCKERIZE_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/dockerize-latest.tar.gz" \
	&& curl --silent --show-error --location --fail --retry 3 --output /tmp/dockerize-linux-amd64.tar.gz $DOCKERIZE_URL \
	&& tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64.tar.gz \
	&& rm -rf /tmp/dockerize-linux-amd64.tar.gz \
	&& dockerize --version
RUN groupadd --gid 3434 circleci \
	&& useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
	&& echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
	&& echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep
ENV HOME /home/circleci
RUN sudo apt-get update -qqy && sudo apt-get install -qqy \
  openssl \
  libssl-dev \
	python-dev \
	python-setuptools \
	apt-transport-https \
	lsb-release
RUN sudo apt-get install gcc-multilib
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
	echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
RUN sudo apt-get update && sudo apt-get install -y google-cloud-sdk && \
	gcloud config set core/disable_usage_reporting true && \
	gcloud config set component_manager/disable_update_check true
ARG sdk_version=sdk-tools-linux-3859397.zip
ARG android_home=/opt/android/sdk
RUN sudo apt-get update && \
	sudo apt-get install --yes \
	xvfb lib32z1 lib32stdc++6 build-essential \
	libcurl4-openssl-dev libglu1-mesa libxi-dev libxmu-dev \
	libglu1-mesa-dev
RUN sudo mkdir -p ${android_home} && \
	sudo chown -R circleci:circleci ${android_home} && \
	curl --silent --show-error --location --fail --retry 3 --output /tmp/${sdk_version} https://dl.google.com/android/repository/${sdk_version} && \
	unzip -q /tmp/${sdk_version} -d ${android_home} && \
	rm /tmp/${sdk_version}
ENV ANDROID_HOME ${android_home}
ENV ADB_INSTALL_TIMEOUT 120
ENV PATH=${ANDROID_HOME}/emulator:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}
RUN mkdir ~/.android && echo '### User Sources for Android SDK Manager' > ~/.android/repositories.cfg
RUN yes | sdkmanager --licenses && sdkmanager --update
RUN sdkmanager \
	"tools" \
	"platform-tools" \
	"emulator"
RUN sdkmanager \
	"build-tools;25.0.0" \
	"build-tools;25.0.1" \
	"build-tools;25.0.2" \
	"build-tools;25.0.3" \
	"build-tools;26.0.1" \
	"build-tools;26.0.2" \
	"build-tools;27.0.0" \
	"build-tools;27.0.1" \
	"build-tools;27.0.2" \
	"build-tools;27.0.3" \
	"build-tools;28.0.0" \
	"build-tools;28.0.3"
RUN sdkmanager "platforms;android-23"

### GOLANG
### https://github.com/docker-library/golang/blob/master/1.11/stretch/Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
	g++ \
	gcc \
	libc6-dev \
	make \
	pkg-config \
	&& rm -rf /var/lib/apt/lists/*
ENV GOLANG_VERSION 1.13.1
RUN set -eux; \
	\
	# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
	amd64) goRelArch='linux-amd64'; goRelSha256='94f874037b82ea5353f4061e543681a0e79657f787437974214629af8407d124' ;; \
	armhf) goRelArch='linux-armv6l'; goRelSha256='7c75d4002321ea4a066dfe13f6dd5168076e9a231317c5afd55e78b86f478e37' ;; \
	arm64) goRelArch='linux-arm64'; goRelSha256='8af8787b7c2a3c0eb3f20f872577fcb6c36098bf725c59c4923921443084c807' ;; \
	i386) goRelArch='linux-386'; goRelSha256='4bf7a961fda7ad892b8824002036de8c0f290df05df2e8f11252d1f8c77dcd8f' ;; \
	ppc64el) goRelArch='linux-ppc64le'; goRelSha256='72422c68dbed013ee321a05dbb97d9c8d6b2c75f347de707138c2c748fc4aceb' ;; \
	s390x) goRelArch='linux-s390x'; goRelSha256='5f0859ae1037ad7af6cdb6d16f638de908fd9de044d463eeab92b9578d4c7c75' ;; \
	*) goRelArch='src'; goRelSha256='81f154e69544b9fa92b1475ff5f11e64270260d46e7e36c34aafc8bc96209358'; \
	echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
	echo >&2; \
	echo >&2 'error: UNIMPLEMENTED'; \
	echo >&2 'TODO install golang-any from jessie-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
	echo >&2; \
	exit 1; \
	fi; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

### RUBY
RUN mkdir -p /usr/local/etc \
	&& { \
	echo 'install: --no-document'; \
	echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc
ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.0
ENV RUBY_DOWNLOAD_SHA256 acb00f04374899ba8ee74bbbcb9b35c5c6b1fd229f1876554ee76f0f1710ff5f
RUN set -ex \
	\
	&& buildDeps=' \
	bison \
	dpkg-dev \
	libgdbm-dev \
	ruby \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends autoconf zlib1g-dev $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
	# hack in "ENABLE_PATH_CHECK" disabling to suppress:
	#   warning: Insecure world writable dir
	&& { \
	echo '#define ENABLE_PATH_CHECK 0'; \
	echo; \
	cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
	--with-openssl \
	--build="$gnuArch" \
	--disable-install-doc \
	--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& apt-get purge -y --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	# rough smoke test
	&& ruby --version && gem --version && bundle --version

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"

RUN gem install bundler -v 1.17.3
RUN gem install bundler -v 2.0.1
RUN gem install bundler -v 2.0.2

### LAST
WORKDIR $GOPATH
USER circleci
FROM circleci/ruby:2.3.6-stretch

USER root

# remove Ruby 2.5.1
RUN rm -rf /usr/local/bin/ruby

# try to fix openssl errors
RUN apt-get -y purge openssl && \
		apt-get -y install libssl1.0-dev

# install Ruby 1.8
RUN wget http://cache.ruby-lang.org/pub/ruby/1.8/ruby-1.8.7.tar.gz && \
    tar -xzvf ruby-1.8.7.tar.gz && \
    rm ruby-1.8.7.tar.gz && \
    cd ruby-1.8.7 && \
    ./configure && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -r ruby-1.8.7

USER circleci
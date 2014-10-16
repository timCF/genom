FROM centos:centos6

RUN yum -y install git
RUN git clone https://github.com/timCF/syspre.git; ./syspre/docker_image/centos6iced.sh


ADD . /opt/genom
RUN cd /opt/genom; mix local.hex --force; mix local.rebar --force
RUN chmod a+x /opt/genom/dockstart.sh
RUN cd /opt/genom; mix deps.compile; mix compile.protocols

EXPOSE 8998
CMD cd /opt/genom; ./dockstart.sh 
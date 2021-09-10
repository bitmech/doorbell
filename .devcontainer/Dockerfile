FROM matspfeiffer/flutter
USER root
RUN apt-get update && apt-get install --yes --no-install-recommends build-essential ruby-full && rm -rf /var/lib/{apt,dpkg,cache,log}
RUN gem install fastlane
USER developer
WORKDIR /home/developer
RUN flutter config --no-analytics && flutter channel stable && flutter upgrade && flutter doctor
ENTRYPOINT ["sleep", "infinity"]
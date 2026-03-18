FROM rockylinux/rockylinux:9

# Install dependencies
COPY rpm/cfengine.rpm /cfengine.rpm
COPY rpm/kaf_07.rpm /kaf_07.rpm
RUN dnf -y install /cfengine.rpm /kaf_07.rpm

# Bootstrap
COPY tester.sh /tester.sh
RUN chmod +x /tester.sh

# Run
ENTRYPOINT ["/tester.sh"]
CMD [""]

#!/bin/bash
# This script is just for the reproduceability of the dummy upgrade packages.
for package in kaf_04 kaf_05 kaf_06; do
    mkdir -p build/{BUILD,RPMS};

    cat <<EOF > "${package}.spec"
Summary: "${package}"
Name: com.teragrep-${package}
Version: 1.0.0
Release: 1
Group: Dummy
License: Dummy
Source: $(pwd)
BuildArch: noarch
BuildRoot: $(pwd)/build/BUILD/%{name}-%{version}-%{release}

%description
%{summary}

%install
mkdir -p \$RPM_BUILD_ROOT/
echo ping > \$RPM_BUILD_ROOT/com.teragrep-${package}.dummy

%files
%defattr(644,root,root)
%defattr(755,root,root)
"/com.teragrep-${package}.dummy"

EOF
    rpmbuild --define "_topdir $(pwd)/build" -bb "${package}.spec";
    mv -v "build/RPMS/noarch/com.teragrep-${package}-1.0.0-1.noarch.rpm" "${package}.rpm";
    rm -rf build/;
done;

rm -rf -- *.spec;

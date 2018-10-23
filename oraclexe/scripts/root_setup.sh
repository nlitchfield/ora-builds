#!/bin/bash

updateOS(){
# Prepare yum with the latest repos.
echo "##############################################################################"
echo "update existing and install new packages"
echo "###############################################################################"

yum -y install yum-utils zip unzip
yum -y update
yum -y localinstall http://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
yum -y localinstall ${XE_RPM}

}

configureXE(){
echo "##############################################################################"
echo "perform XE silent Install"
echo "###############################################################################"
(echo "${APEX_PASSWORD}"; echo "${APEX_PASSWORD}") | /etc/init.d/oracle-xe-18c configure >> /var/tmp/XEsilentinstall.log  2>&1
echo "###############################################################################"
echo "Silent install results"
cat  /var/tmp/XEsilentinstall.log
echo "###############################################################################"
}


createTablespace(){
source oraenv
su oracle -p -c "sqlplus / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
-- install in pdb for XE
alter session set container = XEPDB1;
CREATE TABLESPACE APEX DATAFILE '/opt/oracle/oradata/XE/XEPDB1/apex01.dbf' size 100m autoextend on next 10m;
exit;
EOF"
}

deployApex(){
# Unzip APEX software.
mkdir -p ${APEX_LOCATION}
chown oracle:oinstall ${APEX_LOCATION}
su oracle -p -c "unzip -d ${APEX_LOCATION} ${APEX_ARCHIVE}"
}

installApex(){
source oraenv
# must be run from apex dir 
# because of relative urls in install scripts
cd ${APEX_LOCATION}/apex
su oracle -p -c "sqlplus / as sysdba <<EOF
-- install in pdb for XE
WHENEVER SQLERROR EXIT SQL.SQLCODE;
alter session set container = XEPDB1;
@${APEX_LOCATION}/apex/apexins.sql APEX APEX TEMP /i/
BEGIN
    APEX_UTIL.set_security_group_id( 10 );

    APEX_UTIL.create_user(
        p_user_name       => 'ADMIN',
        p_email_address   => '${APEX_EMAIL}',
        p_web_password    => '${APEX_PASSWORD}',
        p_developer_privs => 'ADMIN' );

    APEX_UTIL.set_security_group_id( null );
    COMMIT;
END;
/
@${APEX_LOCATION}/apex/apex_rest_config.sql ${APEX_PASSWORD} ${APEX_PASSWORD}
@${APEX_LOCATION}/apex/apex_epg_config.sql ${APEX_LOCATION}
alter user APEX_PUBLIC_USER identified by ${APEX_PASSWORD} account unlock;
exit;
EOF"
}

configureEPG(){
su oracle -p -c "sqlplus / as sysdba <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
alter user anonymous account unlock;
alter session set container = XEPDB1;
exec dbms_xdb_config.sethttpport(8081);
exec dbms_xdb_config.sethttpsport(5501);
alter user anonymous account unlock;
EOF"
}

installJDK(){
mkdir -p ${JDK_LOCATION}
cd ${JDK_LOCATION}
tar xvf ${JAVA_ARCHIVE}
alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 11 --slave /usr/bin/javac javac ${JAVA_HOME}/bin/javac
alternatives --set java ${JAVA_HOME}/bin/java
}

installTomcat(){
mkdir ${TOMCAT_LOCATION}
useradd tomcat
chown tomcat:tomcat ${TOMCAT_LOCATION}
su tomcat -p -c "unzip -d ${TOMCAT_LOCATION} ${TOMCAT_ARCHIVE}"
}

installORDS(){
mkdir -p ${ORDS_LOCATION}
chown tomcat:tomcat ${ORDS_LOCATION}
su tomcat -p -c "unzip -d ${ORDS_LOCATION} ${ORDS_ARCHIVE}"
}

configureORDS(){
su tomcat -p -c "mkdir -p ${ORDS_LOCATION}/conf"
su tomcat -p -c "cp ${ORDS_LOCATION}/params/ords_params.properties ${ORDS_LOCATION}/params/ords_params.properties.default"
cat > ${ORDS_LOCATION}/params/ords_params.properties << EOF
db.hostname=localhost.localdomain
db.port=1521
db.servicename=xepdb1
db.username=APEX_PUBLIC_USER
db.password=${APEX_PASSWORD}
migrate.apex.rest=false
plsql.gateway.add=true
rest.services.apex.add=true
rest.services.ords.add=true
schema.tablespace.default=APEX
schema.tablespace.temp=TEMP
standalone.mode=false
user.apex.listener.password=${APEX_PASSWORD}
user.apex.restpublic.password=${APEX_PASSWORD}
user.public.password=${APEX_PASSWORD}
user.tablespace.default=APEX
user.tablespace.temp=TEMP
sys.user=SYS
sys.password=${APEX_PASSWORD}
EOF
chown tomcat:tomcat ${ORDS_LOCATION}/params/ords_params.properties
cd ${ORDS_LOCATION}
su tomcat -p -c "${JAVA_HOME}/bin/java -jar ords.war configdir ${ORDS_LOCATION}/conf"
su tomcat -p -c "${JAVA_HOME}/bin/java -jar ords.war"
}

configureTomcatEnv(){
su tomcat -p -c "cat > /home/tomcat/.bash_profile <<EOF   
export JAVA_HOME=${JAVA_HOME}
export CATALINA_HOME=${CATALINA_HOME}
export CATALINA_BASE=${CATALINA_HOME}  
EOF"
}

configureTomcat(){
su tomcat -p -c "cat > $CATALINA_HOME/conf/tomcat-users.xml <<EOF
\<role rolename=\"manager-gui\"\/\>
\<role rolename=\"admin-gui\"\/\>
\<user username=\"tomcat\" password=${APEX_PASSWORD} roles=\"manager-gui,admin-gui\"\/\>
EOF"
su tomcat -p -c "chmod +x ${CATALINA_HOME}/bin/*.sh"
su tomcat -p -c "${CATALINA_HOME}/bin/startup.sh"
}

deployORDS(){
su tomcat -p -c "mkdir ${CATALINA_HOME}/webapps/i/"
cp -r ${APEX_LOCATION}/apex/images/* ${CATALINA_HOME}/webapps/i/
chown -R tomcat:tomcat ${CATALINA_HOME}/webapps/i/*
su tomcat -p -c "cp $ORDS_LOCATION/ords.war ${CATALINA_HOME}/webapps"
su tomcat -p -c "${CATALINA_HOME}/bin/startup.sh"
}

# env
export ORAENV_ASK=NO
export ORACLE_SID=XE
export ORACLE_HOME=/opt/oracle/product/18c/dbhomeXE
PATH=$PATH:/usr/local/bin:$ORACLE_HOME/bin
export PATH
SOFTWARE_DIR=/vagrant/software
APEX_ARCHIVE=${SOFTWARE_DIR}/apex_18.2.zip
XE_RPM=${SOFTWARE_DIR}/oracle-database-xe-18c-1.0-1.x86_64.rpm
ORDS_ARCHIVE=${SOFTWARE_DIR}/ords-18.3.0.270.1456.zip
JAVA_ARCHIVE=${SOFTWARE_DIR}/openjdk-11.0.1_linux-x64_bin.tar.gz
TOMCAT_ARCHIVE=${SOFTWARE_DIR}/apache-tomcat-9.0.12.zip
APEX_LOCATION=/opt/apex/18.2
ORDS_LOCATION=/opt/ords/18.3
JDK_LOCATION=/opt/java/11
export JAVA_HOME=${JDK_LOCATION}/jdk-11.0.1
TOMCAT_LOCATION=/opt/tomcat
CATALINA_HOME=${TOMCAT_LOCATION}/apache-tomcat-9.0.12
APEX_PASSWORD=C0mplexpassword
APEX_EMAIL=admin@example.com 

updateOS
if [[ $? -ne 0 ]]; then 
  echo "Failed to update O/S Packages correctly"
  exit 1
fi

configureXE
if [[ $? -ne 0 ]]; then 
  echo "Failed to configure XE Package correctly"
  exit 1
fi

createTablespace
if [[ $? -ne 0 ]]; then 
  echo "Failed to create XE Tablespace correctly"
  exit 1
fi

deployApex
if [[ $? -ne 0 ]]; then 
  echo "Failed to extract Apex Package correctly"
  exit 1
fi

installApex
if [[ $? -ne 0 ]]; then 
  echo "Failed to configure Apex correctly"
  exit 1
fi

configureEPG
if [[ $? -ne 0 ]]; then 
  echo "Failed to configure EPG correctly"
  exit 1
fi

installJDK
if [[ $? -ne 0 ]]; then 
  echo "Failed to install and configure JDK correctly"
  exit 1
fi

installTomcat
if [[ $? -ne 0 ]]; then 
  echo "Failed to install tomcat correctly"
  exit 1
fi

installORDS
if [[ $? -ne 0 ]]; then 
  echo "Failed to install ords correctly"
  exit 1
fi

configureORDS
if [[ $? -ne 0 ]]; then 
  echo "Failed to configure ords correctly"
  exit 1
fi

configureTomcatEnv
if [[ $? -ne 0 ]]; then 
  echo "Failed to install ords correctly"
  exit 1
fi

configureTomcat
if [[ $? -ne 0 ]]; then 
  echo "Failed to configure tomcat correctly"
  exit 1
fi

deployORDS
if [[ $? -ne 0 ]]; then 
  echo "Failed to deploy ords to tomcat correctly"
  exit 1
fi

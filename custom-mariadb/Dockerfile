FROM mariadb:10.8

COPY frappe-mariadb.cnf /etc/mysql/mariadb.conf.d/frappe.cnf

RUN ["/bin/bash", "-c", "chmod 444 /etc/mysql/mariadb.conf.d/frappe.cnf"]
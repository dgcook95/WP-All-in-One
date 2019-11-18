#!/bin/bash 
# WordPress General Information BASH script
# By Dylan Cook, 9/26/2018

printf "\n"

read -r -p "Enter domain name: " domain

printf "________________________________________\n\n"

# Variabalizes Document Root

userdir=$(whoami)
dr=$(grep "documentroot" /var/cpanel/userdata/${userdir}/${domain} | awk '{print $2}')

if [ $(ls $dr/wp-config.php 2>/dev/null) ]
then

        # Variable Array: wp-config.php
        DB=($(awk -F "'" '/DB_[NUPH]/{print $4}/table_prefix/{print $2}' $dr/wp-config.php))

        printf "Database Information:\n\n"

        # Echo's DB information
        echo "Database Name: ${DB[0]}"
        echo "Database User: ${DB[1]}"
        echo "Database Password: Plain text passwords are a no-go!"
        echo "Database Host: ${DB[3]}"
        echo "DB Table Prefix: ${DB[4]}"
        printf "________________________________________\n\n"

        # Prints Current Active Theme
        printf "Current Active Theme:\n\n"

        mysql ${DB[0]} -u ${DB[1]} -p${DB[2]} -h ${DB[3]} -e "SELECT option_value FROM ${DB[4]}options WHERE option_name = 'template'\G" 2>/dev/null | awk '/option/{print $2}'
        printf "________________________________________\n"

        # Prints Current Active Plugins
        printf "\nCurrent Active Plugins:\n\n"

        mysql ${DB[0]} -u ${DB[1]} -p${DB[2]} -h ${DB[3]} -e "SELECT option_value FROM ${DB[4]}options WHERE option_name = 'active_plugins'\G" 2>/dev/null | sed '/option_value/s/;/\n/g' | awk -F"[\"/]" '/^s/{print $2}' | grep -v "hello.php"
        printf "________________________________________\n"

        # Prints Home/Site URL:
        printf "\nHome/Site URL\'s:\n\n"
        printf "Site URL: "

        mysql ${DB[0]} -u ${DB[1]} -p${DB[2]} -h ${DB[3]} -e "SELECT option_value FROM ${DB[4]}options WHERE option_name = 'siteurl'\G" 2>/dev/null | awk '/option/{print $2}'
        printf "\n"
        printf "Home URL: "

        mysql ${DB[0]} -u ${DB[1]} -p${DB[2]} -h ${DB[3]} -e "SELECT option_value FROM ${DB[4]}options WHERE option_name = 'home'\G" 2>/dev/null | awk '/option/{print $2}'
        printf "________________________________________\n"

        # Gives Filesize Estimate (only captures contents with wp in the title)
        printf "\nEstimated Filesystem Size:\n\n"
        du -a $dr --max-depth=1 | grep wp | awk '{sum += $1} END {print sum}' | cut -c1-2 | sed "s/$/ MB/"
        printf "________________________________________\n"

        # Prints Size of Database in MB
        printf "\nDatabase Size:\n\n"

        mysql ${DB[0]} -u ${DB[1]} -p${DB[2]} -h ${DB[3]} -Bse "SELECT table_schema ${DB[0]}, ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size MB' FROM information_schema.TABLES GROUP BY table_schema" 2>/dev/null | grep ${DB[0]} | awk '{printf $2}' | sed "s/$/ MB/"
        printf "\n________________________________________\n\n"

else
        printf "Either there is no WordPress Install here, or the domain name is missing a vHost entry. Goodbye!\n\n"
        sleep 1
exit
fi

# Begin Backup Portion
read -r -p "Would you like to take a backup of the website before making changes? [y/n]: " choice

if [ $choice = y ]
then
        # Variable Setting
        timestamp=$(date +%Y%m%d_%H%M%S)
        backup=backup$timestamp
        sql=${DB[0]}_$(date +%Y%m%d_%H%M%S)
        user=$(echo $dr | awk -F "/" '{print $3}')
        mkdir $dr/$backup
        # MySQL Dump
        mysqldump --single-transaction --verbose -u ${DB[1]} -p${DB[2]} ${DB[0]} > $dr/$backup/$sql.sql 2>/dev/null

# Copies all Website Files including .htaccess
for f in $(ls -lah $dr | grep wp | awk '{print $9}');
        do cp -r $f $dr/$backup 2>/dev/null;
done

        cp $dr/.htaccess $dr/$backup 2>/dev/null
        tar -zcf $dr/$backup.tar.gz $dr/$backup 2>/dev/null
        # Changes Ownership to $user and removed backup directory
        chown -R $user:$user $dr/$backup.tar.gz
        rm -rf $dr/$backup
fi

# Check to see if the backup was created
if [ $(ls $dr/$backup.tar.gz 2>/dev/null) ] 
then
        printf "\nBackup has been created! It can be viewed at $dr/$backup.tar.gz  \n\n"
else
        printf "\nBackup was NOT created. Proceed with caution!\n\n"
fi

# Modification Portion Begins
read -r -p "Are you making changes to the website? [y/n]: " choice1

# Checks for backup before making changes. If the backup was never created, the script will end
if [ $choice1 = y ]
then
        if [ $(ls $dr/$backup.tar.gz 2>/dev/null) ]
        then
                while true; do
                printf "\nChoose the corresponding number to the action item:\n\n"
                printf "[1] Deactivate ALL plugins\n"
                printf "[2] Activate ALL plugins\n"
                printf "[3] Manage Themes\n"
                printf "[4] URL Search and Replace\n"
                printf "[5] Flush cache\n"
                printf "[6] Resave Permalinks\n"
                printf "[7] Check for WordPress Version Updates\n"
                printf "[8] Exit script without making changes\n\n"

                read -r -p "Enter your choice[#]: " number

                case $number in
                        1)
                        wp plugin deactivate --all --path=$dr
                        printf "\n"
                        ;;
                        2)
                        wp plugin activate --all --path=$dr
                        printf "\n"
                        ;;
                        3)
                        wp theme list --path=$dr
                        printf "\n\n"
                        read -r -p "Would you like to activate another theme?[y/n]: " choice3
                        if [ $choice3 = y ]
                        then
                                printf "\n"
                                read -r -p "Which theme would you like to activate? (Type theme exactly is at appears): " newtheme
                                wp theme activate $newtheme --path=$dr
                        fi
                        printf "\n"
                        ;;
                        4)
                        printf "[1] HTTP > HTTPS:\n"
                        printf "[2] Full URL Change:\n\n"
                        read -r -p "What type of URL Change?[#]: " type
                        printf "\n"
                        if [ $type = 1 ]
                        then
                                wp search-replace http https --path=$dr --all-tables-with-prefix --dry-run
                                read -r -p "The above is a dry-run. Would you like to move forward with the change? [y/n]: " yesorno
                                if [ $yesorno = y ]
                                then
                                        wp search-replace http https --path=$dr --all-tables-with-prefix
                                else
                                        printf "\n\nURL Search and Replace NOT Performed!\n"
                                fi
                        elif [ $type = 2 ]
                        then
                                read -r -p "What pattern are we replacing? " old1
                                printf "\n"
                                read -r -p "What are we replacing it with? " new1
                                oldpattern=$old1
                                newpattern=$new1
                                wp search-replace $oldpattern $newpattern --path=$dr --all-tables-with-prefix --dry-run
                                read -r -p "The above is a dry-run. Would you like to move forward with the change? [y/n]: " yesorno2
                                if [ $yesorno2 = y ]
                                then
                                        wp search-replace $oldpattern $newpattern --path=$dr --all-tables-with-prefix
                                else
                                        printf "\n\nURL Search and Replace NOT Performed!\n"
                                fi
                        fi
                        printf "\n"
                        ;;
                        5)
                        wp cache flush --path=$dr
                        printf "\n"
                        ;;
                        6)
                        printf "\n"
                        read -r -p "This will update permalink structure to 'post name'. Continue?[y/n]: " permalink
                        if [ $permalink = y ]
                        then
                                wp rewrite structure '/%postname%' --path=$dr
                        fi
                        printf "\n"
                        ;;
                        7)
                        wp core check-update --path=$dr
                        printf "\n"
                        ;;
                        8)
                        printf "\nExiting wpinfo\n\n"
                        sleep 1
                        break
                        ;;
                esac
                done
        else
        printf "\nCreate a backup before making changes!\n\n"
        exit
        fi
else
        printf "\nGoodbye!\n\n"
        sleep 1
exit
fi

#!/bin/bash
# 
# Данная программа предназначена для создания DNS-записей типа A, CNAME, NS, MX
# для доменов, управляемых через аккаунт на сервисе GoDaddy.
# Программа работает только в интерактивном режиме.
# Для запуска программы необходимо просто набрать её имя в командной строке
# без аргументов.
#

### SET VARIABLES ####################################################################

# Секретная пара для аутентификации на GoDaddy
source ./.env
AUTH="Authorization: sso-key ${KEY}:${SECRET}"

### SET FUNCTIONS ####################################################################

# Функция для динамического получения списка dns-доменов, имеющих статус "ACTIVE"
get_domains(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/ | sed 's/}/}\n/g' | sed 's/^,//' | grep -i active | cut -f 2 -d , | cut -f 2 -d : | sed 's/"//g'
}

# Функция для добавления DNS-записей типа A, CNAME, NS
a_record(){
  curl -s -X PATCH -H "${AUTH}" -H "Content-Type: application/json" --data [\{\"type\":\"${NSR}\",\"name\":\"${NAME}\",\"data\":\"${DATA}\",\"ttl\":3600\}] https://api.godaddy.com/v1/domains/$(dns_domains)/records
}

# Функция для добавления DNS-записей типа MX
mx_record(){
  curl -s -X PATCH -H "${AUTH}" -H "Content-Type: application/json" --data [\{\"type\":\"${NSR}\",\"name\":\"${NAME}\",\"data\":\"${DATA}\",\"priority\":${PRI},\"ttl\":3600\}] https://api.godaddy.com/v1/domains/$(dns_domains)/records
}

# Функция для получения имени хоста
host_name(){
  echo -n "(name): "
  read NAME
}

# Функция для получения ip-адреса хоста
ip_addr(){
  echo -n "(ip.ad.dr.es): "
  read IP
}

# Функция для получения FQDN-адреса хоста
fqdn_name(){
  echo -n "(fqdn.name): "
  read FQDN
}

# Функция для получения значения приоритета почтового сервера
prior_id(){
  echo -n "(10|20|etc): "
  read PRI
}

### MODE interactive #################################################################

echo "Данная программа предназначена ТОЛЬКО для ДОБАВЛЕНИЯ DNS-записей типов"
echo "A, CNAME, NS, MX"
echo "Если вы не знаете о чём идёт речь лучше откажитесь от использования данной программы"
echo " "
echo "Для продолжения введите \"yes\" или \"no\" для выхода из программы"
echo -n '(yes|no): '
read ANSWER
case ${ANSWER} in
  [yY]|[yY][eE][sS])
    echo "Он сказал - \"Поехали!\""
    echo "..."
    echo " "
  ;;
  *)
    echo "Goodbye!"
    exit 1
esac

# Выбор DNS-домена
echo "Для продолжения выберите номер строки с именем требуемого dns-домена"
while [ 1 ]
 do
    select ONEDOMAIN in $(get_domains) quit
      do
        # Если выбрано quit значит выход из программы
        if [ ${ONEDOMAIN} = quit ]; then
          echo "Goodbye!"
          exit 1
        fi
      
        # В остальных случаях используем выбранный вариант и выходим из цикла
        dns_domains(){
          echo ${ONEDOMAIN}
        }

        break
      done

    # Проверяем правильность выбора
    if [ ! $(dns_domains) ]
      then
        echo "Выберите один из предложенных вариантов!"
      else
        break
    fi
  done

echo " "
echo "Вы выбрали DNS-домен $(dns_domains)"
echo "..."
echo " "

# Выбор типа DNS-записей
echo "Выберите тип DNS-записи которую вы хотите добавить в домен $(dns_domains)"
echo "DNS-запись типа \"A\" создаёт запись для реального узла (хоста) сети Интернет"
echo "DNS-запись типа \"CNAME\" создаёт запись типа символьной ссылки на существующую запись типа \"A\""
echo "DNS-запись типа \"NS\" создаёт запись для DNS-серверов"
echo "DNS-запись типа \"MX\" создаёт запись для почтовых серверов данного домена"
echo " "
echo "Для продолжения введите тип создаваемой DNS-записи"

while [ ! ${NSR} ]
  do
    echo -n '(A|CNAME|NS|MX): '
    read NSRECORD

    case ${NSRECORD} in
      [Aa])
        while [ 1 ]
          do
            NSR=A
            echo "Введите имя узла (хоста) без доменной части (non-FQDN) для домена $(dns_domains)"
            echo "Для домена по умолчанию используется символ \"@\""
            host_name
            echo "-"
            echo "Введите ip-адрес узла (хоста)"
            ip_addr
            echo "-"
            echo " "
            echo "Вы хотите создать DNS-запись типа ${NSR} для домена $(dns_domains) со следующими параметрами"
            echo "name: ${NAME}, data: ${IP}"
            echo -n '(yes|no): '
            read ANSWER_A
            case ${ANSWER_A} in
              [yY]|[yY][eE][sS])
                echo "Да! Есть! Так точно!"
                DATA=${IP}
                a_record
                break
              ;;
              *)
                echo " "
                echo "!!!"
                echo "!!! Повторите ввод имени хоста и его ip-адреса для DNS-записи типа ${NSR}"
                echo "!!!"
                echo " "
            esac
          done
      ;;
      [Cc][Nn][Aa][Mm][Ee])
        while [ 2 ]
          do
            NSR=CNAME
            echo "Введите имя узла (хоста) для DNS-записи типа ${NSR} без доменной части (non-FQDN) для домена $(dns_domains)"
            host_name
            echo "-"
            echo "Введите полное FQDN-имя узла (хоста) на который будет указывать создаваемая DNS-запись типа ${NSR}"
            echo "Например, dev.mlm-soft.com"
            fqdn_name
            echo "-"
            echo " "
            echo "Вы хотите создать DNS-запись типа ${NSR} для домена $(dns_domains) со следующими параметрами"
            echo "name: ${NAME}, data: ${FQDN}"
            echo -n '(yes|no): '
            read ANSWER_CNAME
            case ${ANSWER_CNAME} in
              [yY]|[yY][eE][sS])
                echo "Да! Есть! Так точно!"
                DATA=${FQDN}
                a_record
                break
              ;;
              *)
                echo " "
                echo "!!!"
                echo "!!! Повторите ввод имени хоста и FQDN-имени хоста назначения для DNS-записи типа ${NSR}"
                echo "!!!"
                echo " "
            esac 
          done
      ;;
      [Nn][Ss])
        while [ 3 ]
          do
            NSR=NS
            echo "Введите имя DNS-домена для которого вы хотите создать запись обслуживающего DNS-сервера или включить делегирование"
            echo "Для домена по умолчанию используется символ \"@\""
            host_name
            echo "-"
            echo "Введите полное FQDN-имя DNS-сервера на который будет указывать создаваемая DNS-запись типа ${NSR}"
            echo "Например, ns.mlm-soft.com"
            fqdn_name
            echo "-"
            echo " "
            echo "Вы хотите создать DNS-запись типа ${NSR} для домена $(dns_domains) со следующими параметрами"
            echo "name: ${NAME}, data: ${FQDN}"
            echo -n '(yes|no): '
            read ANSWER_NS
            case ${ANSWER_NS} in
              [yY]|[yY][eE][sS])
                echo "Да! Есть! Так точно!"
                DATA=${FQDN}
                a_record
                break
              ;;
              *)
                echo " "
                echo "!!!"
                echo "!!! Повторите ввод имени DNS-домена и FQDN-имени DNS-сервера для DNS-записи типа ${NSR}"
                echo "!!!"
                echo " "
            esac 
          done
      ;;
      [Mm][Xx])
        while [ 4 ]
          do
            NSR=MX
            NAME=@
            echo "Введите полное FQDN-имя почтового сервера на который будет указывать создаваемая DNS-запись типа ${NSR}"
            echo "Например, smtp.mlm-soft.com"
            fqdn_name
            echo "-"
            echo "Введите приоритет для указанного почтового сервера"
            echo "Значение приоритета должно быть положительным и целочисленным, например, \"5\" или \"10\" и т.п."
            echo "Для основного почтового сервера численное значение приоритета должно быть самым низким" 
            prior_id
            echo "-"
            echo " "
            echo "Вы хотите создать DNS-запись типа ${NSR} для домена $(dns_domains) со следующими параметрами"
            echo "name: ${NAME}, data: ${FQDN}, priority: ${PRI}"
            echo -n '(yes|no): '
            read ANSWER_MX
            case ${ANSWER_MX} in
              [yY]|[yY][eE][sS])
                echo "Да! Есть! Так точно!"
                DATA=${FQDN}
                mx_record
                break
              ;;
              *)
                echo " "
                echo "!!!"
                echo "!!! Повторите ввод FQDN-имени почтового сервера и значение приоритета для DNS-записи типа ${NSR}"
                echo "!!!"
                echo " "
            esac 
          done
      ;;
      *)
        echo "Вы указали неверный/несуществующий тип DNS-записи"
    esac
  done

echo " "
echo "Goodbye!"

exit 0

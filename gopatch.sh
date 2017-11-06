#!/bin/bash
#
# Данная программа предназначена для изменения DNS-записей типа A, CNAME
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

# Функция для получения файла описания DNS-zone для выбранного домена
golist(){
  curl -s -X GET -H "${AUTH}" https://api.godaddy.com/v1/domains/$(dns_domains)/records | sed 's/}/}\n/g' | sed 's/\[/\[\n/g'
}

# Функция подготовки записей DNS-records для выборки
select_str(){
  golist | sed '/TXT/ d' | sed '/NS/ d' | sed '/MX/ d' | sed '/^\[/ d' | sed '/^\]/ d' | sed 's/^.*type/"type/' | sed 's/,"ttl.*$//'
}

# Функция определения типа изменяемой DNS-записи
patch_str_type(){
  echo "$(patch_str)" | cut -f 1 -d "," | cut -f 2 -d ":" | sed 's/"//g'
}

# Функция определения имени хоста для изменяемой DNS-записи
patch_str_name(){
  echo "$(patch_str)" | cut -f 2 -d "," | cut -f 2 -d ":" | sed 's/"//g'
}

# Функция определения данных изменяемой DNS-записи
patch_str_data(){
  echo "$(patch_str)" | cut -f 3 -d "," | cut -f 2 -d ":" | sed 's/"//g'
}

### MODE interactive #################################################################

echo " "
echo "!!!ATTENTION!!! Данная программа предназначена ТОЛЬКО для ИЗМЕНЕНИЯ DNS-записей"
echo "типов A, CNAME в файле описания DNS-zone средствами API GoDaddy"
echo "Для изменения DNS-записей типов NS, MX и TXT используйте последовательно скрипты"
echo "godelete.sh и goadd.sh"
echo " "
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

### Select procedure #################################################################

# Создадим резервную копию для выбранного домена
echo "Создадим резервную копию для выбранного домена"

if [ ! `ls ./ | grep gobackup.sh` ]
  then
      GOBACKUPPATH=`find / -name "gobackup.sh" 2>/dev/null | grep -m 1 '/godaddy-api/'`
  else
      GOBACKUPPATH='./gobackup.sh'
fi

${GOBACKUPPATH} $(dns_domains)

# Выбираем данные для изменения
echo " "
echo "Выберите из списка DNS-запись, предназначенную для изменения, указав номер строки:"
echo " "

while [ 1 ]
  do
    select PATCHSTR in $(select_str) quit
      do
        # Если выбрано quit значит выход из программы
        if [ ${PATCHSTR} = quit ]; then
          echo "Goodbye!"
          exit 1
        fi
      
        # В остальных случаях используем выбранный вариант и выходим из цикла
        patch_str(){
          echo ${PATCHSTR}
        }

        break
      done

    # Проверяем правильность выбора
    if [ ! $(patch_str) ]
      then
        echo " "
        echo "Выберите один из предложенных вариантов!"
      else
        break
    fi
  done

echo " "
echo "Вы выбрали для изменения следующую DNS-запись:"
echo "$(patch_str)"
echo " "
echo "Для DNS-записей типа \"А\" возможно только изменение IP-адреса."
echo "Для DNS-записей типа \"CNAME\" возможно только переопределение адреса перенаправления."
echo "Для продолжения введите \"yes\" или \"no\" для выхода из программы"
echo -n '(yes|no): '
read ANSWERNEW
case ${ANSWERNEW} in
  [yY]|[yY][eE][sS])
    echo "Он сказал - \"Поехали!\""
    echo "..."
    echo " "
  ;;
  *)
    echo "Goodbye!"
    exit 1
esac

### Patch procedure ##################################################################

# Получаем новые данные для внесения изменений в выбранные DNS-записи
while [ 2 ]
  do
    if [ $(patch_str_type) = A ]
      then
        echo "Введите новый IP-адрес для А-записи name:$(patch_str_name) с IP-адресом data:$(patch_str_data)"
        echo -n '(ip.ad.dr.es): '
        read PATCHDATA
      else
        echo "Введите новый FQDN-адрес для CNAME-записи name:$(patch_str_name) с адресом перенаправления data:$(patch_str_data)"
        echo -n '(fqdn.name): '
        read PATCHDATA
    fi
    
    # Проверяем правильность выбора
    if [ ! ${PATCHDATA} ]
      then
        echo " "
        echo "Введите корректные данные! Или нажмите Ctrl+C для выхода из программы."
      else
        echo " "
        echo "Новые данные для внесения изменения:"
        echo "\"type\":\"$(patch_str_type)\",\"name\":\"$(patch_str_name)\",\"data\":\"${PATCHDATA}\""
        echo -n 'Всё верно? (yes|no): '
        read ANSWERFINE
        case ${ANSWERFINE} in
          [yY]|[yY][eE][sS])
            echo "Он сказал - \"Поехали!\""
            echo "..."
            echo " "
            break
          ;;
          *)
            echo "Повторите ввод новых данных!"
        esac
    fi
  done

# Применяем внесённые изменения
curl -s -X PUT -H "${AUTH}" -H "Content-Type: application/json" --data [\{\"data\":\"${PATCHDATA}\",\"ttl\":3600\}] https://api.godaddy.com/v1/domains/$(dns_domains)/records/$(patch_str_type)/$(patch_str_name)

echo " "
echo "Goodbye!"

exit 0

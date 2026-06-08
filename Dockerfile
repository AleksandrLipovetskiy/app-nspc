FROM nginx:alpine

# Копируем конфиг nginx с отключённым daemon mode и настройками безопасности
COPY nginx.conf /etc/nginx/nginx.conf

COPY index.html /usr/share/nginx/html/
COPY style.css  /usr/share/nginx/html/
COPY logik.js   /usr/share/nginx/html/

# Даём права nginx user (uid=101) на нужные директории
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

USER nginx  # ← запускаем не от root

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
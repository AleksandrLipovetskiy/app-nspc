# app-nspc - Тестовое веб-приложение

Простое веб-приложение на HTML/CSS/JavaScript для развертывания в Kubernetes и Yandex.Cloud

## Структура  

```
index.html          # Главная страница (HTML)
style.css           # Стили (CSS)
logik.js            # JavaScript логика
Dockerfile          # Multi-stage Docker образ на базе nginx:alpine
k8s/                # Kubernetes манифесты
  namespace.yaml    # Namespace app-nspc
  deployment.yaml   # Deployment с 2 реплики
  service.yaml      # LoadBalancer Service
.github/workflows/
  ci.yml            # Build образа и Push в Yandex Container Registry
  cd.yml            # Deploy в Kubernetes на релиз (git tag v*.*)
```

## Docker

### Локальная сборка

```bash
docker build -t app-nspc:latest .
docker run -p 8080:80 app-nspc:latest
```

Перейди на http://localhost:8080

### Пуш в регистр

```bash
docker login cr.yandex -u json_key -p "$(yc iam create-token)"
docker tag app-nspc:latest cr.yandex/<folder>/app-nspc:v1.0.0
docker push cr.yandex/<folder>/app-nspc:v1.0.0
```

## Kubernetes

### Применение манифестов

```bash
# Вся сразу
kubectl apply -f k8s/

# Или по отдельности
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Проверка

```bash
# Pods
kubectl get pods -n app-nspc

# Service (узнай LoadBalancer IP)
kubectl get svc -n app-nspc

# Логи
kubectl logs -n app-nspc deployment/app-nspc
```

### Доступ

```bash
# Если есть LoadBalancer IP
EXTERNAL_IP=$(kubectl get svc app-nspc -n app-nspc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP

# Или port-forward
kubectl port-forward -n app-nspc svc/app-nspc 8080:80
# http://localhost:8080
```

## GitHub Actions CI/CD

### CI Workflow (ci.yml)

**Триггеры:**
- any `push` в main/develop
- изменения в Dockerfile,  *.html, *.css, *.js
- `workflow_dispatch` (ручной запуск)

**Действия:**
1. Checkout code
2. Setup Docker Buildx
3. Login в Yandex Container Registry
4. Build & Push образа с тегами:
   - `cr.yandex/<folder>/app-nspc:<short-sha>`
   - `cr.yandex/<folder>/app-nspc:latest`

### CD Workflow (cd.yml)

**Триггеры:**
- `push` tag `v*.*.*` (e.g., `v1.0.0`, `v1.2.3`)
- `workflow_dispatch` (ручной deploy конкретной версии)

**Действия:**
1. Checkout code
2. Получить kubeconfig через Yandex Cloud CLI и IAM-токен
3. Deploy: создание или обновление Deployment
4. Rollout status check
5. Создание Service (если не существует)
6. Показать статус

## GitHub Secrets (для app-nspc репозитория)

Добавь в Settings → Secrets and variables → Actions:

```
YC_FOLDER_ID          # ID папки в Yandex.Cloud
YC_CLOUD_ID           # ID облака в Yandex.Cloud
YC_IAM_TOKEN          # IAM-токен для доступа в Yandex Cloud и реестр
SSH_PUBLIC_KEY        # публичный SSH-ключ (если используется в инфраструктурном репозитории)
```

Пример подготовки:

```bash
# IAM token
yc iam create-token --service-account-id <SERVICE_ACCOUNT_ID>
# Скопируй значение токена в GitHub Secret YC_IAM_TOKEN
```

> Для app-nspc workflow больше не требуется сохранять `KUBECONFIG` как секрет: GitHub Actions генерирует его на лету через `yc managed-kubernetes cluster get-credentials`.

## Развертывание

### На коммит в main

```bash
git add .
git commit -m "Update app"
git push origin main
```

→ GitHub Actions автоматически соберет образ и пушит в registry

### На релиз

```bash
# Создай тег версии
git tag v1.0.0
git push origin v1.0.0
```

→ GitHub Actions:
1. Собирает образ и пушит: `cr.yandex/<folder>/app-nspc:v1.0.0`
2. Задеплоивает в Kubernetes (namespace app-nspc)
3. Показывает статус deployment

## Мониторинг

Приложение автоматически мониторится через kube-prometheus-stack:

```bash
# Метрики в Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090 → query: container_cpu_usage_seconds_total

# Графики в Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000 (admin/admin)
```

## Troubleshooting

### Образ не собирается

```bash
# Проверить GitHub Actions логи
# GitHub → Actions → последний run → Build and push Docker image

# Локально проверь Dockerfile
docker build -t test:latest .
```

### Deployment failed

```bash
# Описание проблемы
kubectl describe deployment app-nspc -n app-nspc

# Логи пода
kubectl logs -n app-nspc <pod-name>

# Статус
kubectl get pods -n app-nspc -o wide
```

### Pull image failed

```bash
# Create docker-registry secret
kubectl create secret docker-registry regcred \
  --docker-server=cr.yandex \
  --docker-username=json_key \
  --docker-password="$(yc iam create-token)" \
  --docker-email=admin@example.com \
  -n app-nspc

# Update deployment.yaml: imagePullSecrets
# - name: regcred
```

### Доступ к LoadBalancer

```bash
# Дождаться, пока IP появится (может быть 1-2 минуты)
kubectl get svc app-nspc -n app-nspc --watch

# Или
kubectl get svc app-nspc -n app-nspc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

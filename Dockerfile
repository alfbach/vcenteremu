FROM registry.access.redhat.com/ubi9/python-311:latest

LABEL maintainer="vcenteremu" \
      description="vCenter API emulator powered by RVtools XLSX exports" \
      io.k8s.display-name="vCenter Emulator" \
      io.openshift.tags="python,fastapi,vcenter,emulator"

USER 0

WORKDIR /opt/app

COPY requirements.txt pyproject.toml README.md ./
COPY app ./app

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir . && \
    mkdir -p /var/lib/vcenteremu/uploads && \
    chgrp -R 0 /var/lib/vcenteremu /opt/app && \
    chmod -R g+rwX /var/lib/vcenteremu /opt/app

ENV VCENTEREMU_HOST=0.0.0.0 \
    VCENTEREMU_PORT=8181 \
    VCENTEREMU_UPLOAD_DIR=/var/lib/vcenteremu/uploads \
    VCENTEREMU_WORKERS=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8181

USER 1001

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8181"]

resource "aws_sagemaker_notebook_instance" "notebook" {
  name            = "${var.app_name}-notebook"
  instance_type   = "ml.t2.medium"
  role_arn        = aws_iam_role.notebook.arn
  subnet_id       = var.vpc_private_subnets[0]
  security_groups = [aws_security_group.notebook_sg.id]
  kms_key_id      = aws_kms_key.kms_key.arn


  platform_identifier = "notebook-al2-v2" # Amazon Linux 2 + JupyterLab 3 al2-v3 
  volume_size         = 5

  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.pytorch_venv.name

  # Block direct internet access (default is 'Enabled')
  direct_internet_access = "Disabled"
}


resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "pytorch_venv" {
  name = "install-pytorch-venv"
  on_start = base64encode(<<EOF
#!/bin/bash
set -e
LOGFILE="/home/ec2-user/SageMaker/pytorch-install.log"
INSTALL_SCRIPT="/home/ec2-user/SageMaker/setup_pytorch.sh"
SETUP_SCRIPT="/home/ec2-user/SageMaker/setup_python.sh"
VENV_DIR="/home/ec2-user/python-venv"
PYTHON_VERSION="3.10.13"
FLAG_FILE="/home/ec2-user/SageMaker/.python_installed"

# Ensure the SageMaker directory exists and has correct permissions
sudo -u ec2-user mkdir -p /home/ec2-user/SageMaker
sudo chown -R ec2-user:ec2-user /home/ec2-user/SageMaker

# Start with a clean log file owned by ec2-user
sudo -u ec2-user touch "$LOGFILE"
sudo -u ec2-user bash -c "echo \"---- PyTorch Setup Started: $(date) ----\" > \"$LOGFILE\""

# Create the Python installation script that will run in the background
sudo -u ec2-user tee "$SETUP_SCRIPT" > /dev/null << EOF2
#!/bin/bash
LOGFILE="/home/ec2-user/SageMaker/python-install.log"
PYTHON_VERSION="3.10.13"
FLAG_FILE="/home/ec2-user/SageMaker/.python_installed"
VENV_DIR="/home/ec2-user/python-venv"
PYTHON_PATH="/usr/local/bin/python3.10"
echo "[INFO] Starting Python \$PYTHON_VERSION installation..." >> "\$LOGFILE"

# Install development tools and dependencies
sudo yum update -y >> "\$LOGFILE" 2>&1
sudo yum groupinstall -y "Development Tools" >> "\$LOGFILE" 2>&1
sudo yum install -y openssl-devel bzip2-devel libffi-devel zlib-devel readline-devel sqlite-devel >> "\$LOGFILE" 2>&1

# Download and install Python 3.10.13
cd /tmp
echo "[INFO] Downloading Python \$PYTHON_VERSION..." >> "\$LOGFILE"
curl -L -O https://www.python.org/ftp/python/\$PYTHON_VERSION/Python-\$PYTHON_VERSION.tgz >> "\$LOGFILE" 2>&1

# Verify download was successful
if [ ! -f "/tmp/Python-\$PYTHON_VERSION.tgz" ]; then
  echo "[ERROR] Failed to download Python \$PYTHON_VERSION" >> "\$LOGFILE"
  echo "[INFO] Checking what's in the directory:" >> "\$LOGFILE"
  ls -la /tmp >> "\$LOGFILE" 2>&1
  exit 1
fi

echo "[INFO] Extracting Python \$PYTHON_VERSION..." >> "\$LOGFILE"
tar -xzf Python-\$PYTHON_VERSION.tgz >> "\$LOGFILE" 2>&1

# Verify extraction was successful
if [ ! -d "/tmp/Python-\$PYTHON_VERSION" ]; then
  echo "[ERROR] Failed to extract Python \$PYTHON_VERSION" >> "\$LOGFILE"
  echo "[INFO] Checking what's in the directory:" >> "\$LOGFILE"
  ls -la /tmp >> "\$LOGFILE" 2>&1
  exit 1
fi
cd Python-\$PYTHON_VERSION
echo "[INFO] Configuring Python \$PYTHON_VERSION..." >> "\$LOGFILE"
./configure --enable-optimizations --with-ensurepip=install >> "\$LOGFILE" 2>&1
echo "[INFO] Building Python \$PYTHON_VERSION..." >> "\$LOGFILE"
make -j \$(nproc) >> "\$LOGFILE" 2>&1
echo "[INFO] Installing Python \$PYTHON_VERSION..." >> "\$LOGFILE"
sudo make altinstall >> "\$LOGFILE" 2>&1

# Create symlink for easier access
echo "[INFO] Creating symlinks..." >> "\$LOGFILE"
sudo ln -sf /usr/local/bin/python3.10 /usr/bin/python3.10
sudo ln -sf /usr/local/bin/pip3.10 /usr/bin/pip3.10

# Verify Python installation
echo "[INFO] Verifying Python installation:" >> "\$LOGFILE"
which python3.10 >> "\$LOGFILE" 2>&1
python3.10 --version >> "\$LOGFILE" 2>&1
echo "[INFO] Python \$PYTHON_VERSION installed successfully" >> "\$LOGFILE"
# Create venv if it does not exist
if [ -d "\$VENV_DIR" ]; then
  echo "[INFO] Removing existing virtual environment..." >> "\$LOGFILE"
  rm -rf "\$VENV_DIR"
fi
echo "[INFO] Creating new Python \$PYTHON_VERSION virtual environment..." >> "\$LOGFILE"
\$PYTHON_PATH -m venv "\$VENV_DIR" >> "\$LOGFILE" 2>&1

# Verify venv creation
echo "[INFO] Verifying virtual environment:" >> "\$LOGFILE"
ls -la "\$VENV_DIR" >> "\$LOGFILE" 2>&1
ls -la "\$VENV_DIR/bin" >> "\$LOGFILE" 2>&1

# Create flag file to indicate installation is complete
touch "\$FLAG_FILE"
echo "[INFO] Python setup completed at \$(date)" >> "\$LOGFILE"
EOF2

# Create the PyTorch installation script that will check for Python installation
sudo -u ec2-user tee "$INSTALL_SCRIPT" > /dev/null << EOF3
#!/bin/bash
VENV_DIR="/home/ec2-user/python-venv"
LOGFILE="/home/ec2-user/SageMaker/pytorch-install.log"
FLAG_FILE="/home/ec2-user/SageMaker/.python_installed"
KERNEL_NAME="python310-pytorch"
DISPLAY_NAME="Python 3.10.x (PyTorch)"
KERNEL_DIR="\$HOME/.local/share/jupyter/kernels/\$KERNEL_NAME"

# Wait for Python installation to complete (max 30 minutes)
MAX_WAIT=1800
WAITED=0
echo "[INFO] Waiting for Python installation to complete..." >> "\$LOGFILE"
while [ ! -f "\$FLAG_FILE" ] && [ \$WAITED -lt \$MAX_WAIT ]; do
  sleep 10
  WAITED=\$((WAITED + 10))
  echo "[INFO] Still waiting for Python installation... (\$WAITED seconds)" >> "\$LOGFILE"
done
if [ ! -f "\$FLAG_FILE" ]; then
  echo "[ERROR] Python installation timed out after \$WAITED seconds" >> "\$LOGFILE"
  exit 1
fi

# Wait a bit more to ensure file system sync
sleep 5

# Check if venv exists
if [ ! -d "\$VENV_DIR" ] || [ ! -f "\$VENV_DIR/bin/activate" ]; then
  echo "[ERROR] Virtual environment not found or incomplete" >> "\$LOGFILE"
  ls -la "\$VENV_DIR" >> "\$LOGFILE" 2>&1 || echo "VENV_DIR does not exist" >> "\$LOGFILE"
  exit 1
fi

# Use the full path to activate script
echo "[INFO] Activating virtual environment" >> "\$LOGFILE"
source "\$VENV_DIR/bin/activate"

# Verify we're in the virtual environment
which python >> "\$LOGFILE" 2>&1
echo "Python version: \$(python --version)" >> "\$LOGFILE" 2>&1
echo "[INFO] Installing pip packages..." >> "\$LOGFILE"

# Update pip first
"\$VENV_DIR/bin/pip" install --upgrade pip >> "\$LOGFILE" 2>&1
# Install required packages using the full path to pip
"\$VENV_DIR/bin/pip" install wheel setuptools >> "\$LOGFILE" 2>&1
# Install NumPy and Pandas
echo "[INFO] Installing NumPy and Pandas..." >> "\$LOGFILE"
"\$VENV_DIR/bin/pip" install numpy pandas matplotlib >> "\$LOGFILE" 2>&1
# Install PyTorch
echo "[INFO] Installing PyTorch..." >> "\$LOGFILE"
"\$VENV_DIR/bin/pip" install torch --index-url https://download.pytorch.org/whl/cpu >> "\$LOGFILE" 2>&1
# Install Jupyter related packages
echo "[INFO] Installing Jupyter packages..." >> "\$LOGFILE"
"\$VENV_DIR/bin/pip" install ipykernel jupyter_client >> "\$LOGFILE" 2>&1

# Remove any existing kernel with the same name
if [ -d "\$KERNEL_DIR" ]; then
  echo "[INFO] Removing existing kernel directory..." >> "\$LOGFILE"
  rm -rf "\$KERNEL_DIR"
fi

# Create kernel directory
mkdir -p "\$KERNEL_DIR"

# Create kernel.json file manually
cat > "\$KERNEL_DIR/kernel.json" << EOK
{
 "argv": [
  "\$VENV_DIR/bin/python",
  "-m",
  "ipykernel_launcher",
  "-f",
  "{connection_file}"
 ],
 "display_name": "\$DISPLAY_NAME",
 "language": "python",
 "metadata": {
  "debugger": true
 }
}
EOK

echo "[INFO] Created custom kernel.json:" >> "\$LOGFILE"
cat "\$KERNEL_DIR/kernel.json" >> "\$LOGFILE"

# Verify package installations with simple version checks
echo "[INFO] Verifying package installations:" >> "\$LOGFILE"
echo "Python version:" >> "\$LOGFILE"
"\$VENV_DIR/bin/python" --version >> "\$LOGFILE" 2>&1

echo "NumPy version:" >> "\$LOGFILE"
"\$VENV_DIR/bin/python" -c 'import numpy; print(numpy.__version__)' >> "\$LOGFILE" 2>&1

echo "Pandas version:" >> "\$LOGFILE"
"\$VENV_DIR/bin/python" -c 'import pandas; print(pandas.__version__)' >> "\$LOGFILE" 2>&1

echo "PyTorch version:" >> "\$LOGFILE"
"\$VENV_DIR/bin/python" -c 'import torch; print(torch.__version__)' >> "\$LOGFILE" 2>&1

echo "---- PyTorch Install Completed: \$(date) ----" >> "\$LOGFILE"
EOF3

# Make scripts executable
sudo -u ec2-user chmod +x "$SETUP_SCRIPT"
sudo -u ec2-user chmod +x "$INSTALL_SCRIPT"

# Check if Python is already installed
if [ -f "$FLAG_FILE" ] && command -v python3.10 &> /dev/null; then
  sudo -u ec2-user bash -c "echo \"[INFO] Python 3.10 is already installed, skipping installation\" >> \"$LOGFILE\""
else
  # Start Python installation in the background
  sudo -u ec2-user bash -c "echo \"[INFO] Starting Python installation in the background\" >> \"$LOGFILE\""
  sudo -u ec2-user nohup bash "$SETUP_SCRIPT" >> "$LOGFILE" 2>&1 &
fi

# Start PyTorch installation in the background
sudo -u ec2-user bash -c "echo \"[INFO] Scheduling PyTorch installation\" >> \"$LOGFILE\""
sudo -u ec2-user nohup bash "$INSTALL_SCRIPT" >> "$LOGFILE" 2>&1 &

# Exit successfully to allow the notebook to start
echo "[INFO] Lifecycle configuration script completed, notebook will start while installation continues in background" >> "$LOGFILE"
exit 0
EOF
  )
}

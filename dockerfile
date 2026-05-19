# Use the specified base image
FROM dustynv/ros:humble-desktop-l4t-r36.4.0

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH=/usr/local/bin:$PATH

# ================= Basic System Setup ======================
# Update the system and install essential tools
RUN rm -rf /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    git \
    vim nano \
    ca-certificates \
    libssl-dev \
    libffi-dev \
    tmux \
    sudo \
    usbutils \
    bash-completion \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure the `python` command points to `python3`
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*



# ================= Custom User Setup ======================
# Create a non-root user 'work'
RUN useradd -ms /bin/bash work

# Grant sudo privileges to the 'work' user
RUN echo "work ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set a custom hostname
RUN echo "aa" > /etc/hostname

# Set the working directory and give permissions to the 'work' user
RUN mkdir -p /workspace && chown work:work /workspace
WORKDIR /workspace


# ================= Custom Shell Environment ======================
# Customize PS1 prompt to make it more noticeable
RUN echo "PS1='\[\033[1;31m\]\u@\[\033[1;34m\]\h\[\033[0m\]:\[\033[1;33m\]\w\[\033[0m\]\$ '" >> /home/work/.bashrc

# Enable bash-completion
RUN echo "source /usr/share/bash-completion/bash_completion" >> /home/work/.bashrc



# Switch to root user temporarily for install tool
USER root


# ================= Upgrade Tools and Install Python ======================
# Upgrade pip
RUN python3 -m pip install --upgrade pip --index-url https://pypi.org/simple/


# ================= Camera Tool ======================
RUN apt-get update && apt-get install -y --no-install-recommends \
    v4l-utils \
    ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*



# ================= ROS2 Packages ======================

RUN apt update
RUN apt purge -y \
    opencv-dev \
    opencv-libs \
    opencv-licenses \    
    opencv-main \
    opencv-python \
    opencv-scripts


    
# Fetch and install the ROS APT source package
RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(lsb_release -c | awk '{print $2}')_all.deb" && \
    dpkg -i /tmp/ros2-apt-source.deb && \
    rm /tmp/ros2-apt-source.deb

# Clean up apt cache
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ur \
    ros-humble-xacro
# Install realsense sdk
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE || sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE

RUN add-apt-repository "deb https://librealsense.intel.com/Debian/apt-repo $(lsb_release -cs) main" -u

RUN apt-get update && apt-get install -y --no-install-recommends \
    librealsense2-utils \
    librealsense2-dev \
    librealsense2-udev-rules \ 
    && apt-get clean && rm -rf /var/lib/apt/lists/*c
# ================= ROS2 Setup ======================

# USER root
ENV LOGNAME root
ENV DEBIAN_FRONTEND noninteractive

# #This symbolic link is needed to use the streaming features on Jetson inside a container
RUN ln -sf /usr/lib/aarch64-linux-gnu/tegra/libv4l2.so.0 /usr/lib/aarch64-linux-gnu/libv4l2.so

###Gr00t setup####

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-dev \
      libsm6 \
      libxext6 \
      ffmpeg \
      libhdf5-serial-dev \
      libtesseract-dev \
      libgtk-3-0 \
      libtbb12 \
      libtbb2 \
      libatlas-base-dev \
      libopenblas-dev \
      build-essential \
      python3-setuptools \
      make \
      cmake \
      nasm \
      git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
    
RUN wget https://developer.download.nvidia.com/compute/cudss/0.6.0/local_installers/cudss-local-tegra-repo-ubuntu2204-0.6.0_0.6.0-1_arm64.deb && \
    dpkg -i cudss-local-tegra-repo-ubuntu2204-0.6.0_0.6.0-1_arm64.deb && \
    cp /var/cudss-local-tegra-repo-ubuntu2204-0.6.0/cudss-*-keyring.gpg /usr/share/keyrings/ && \
    chmod 777 /tmp && \
    apt-get update && \
    apt-get -y install cudss && \
    rm -f cudss-local-tegra-repo-ubuntu2204-0.6.0_0.6.0-1_arm64.deb && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

COPY pyproject.toml .

# ================= Finalize Container Configuration ======================
RUN groupadd -f video && groupadd -f i2c && groupadd -f -r gpio &&\
    usermod -aG sudo,video,i2c,gpio work
USER work

RUN echo "source /opt/ros/humble/setup.bash" >> /home/work/.bashrc

RUN echo "export PIP_INDEX_URL='https://pypi.jetson-ai-lab.io/jp6/cu126'" >> /home/work/.bashrc
#ENV PIP_INDEX_URL='https://pypi.jetson-ai-lab.io/jp6/cu126'
ENV PIP_INDEX_URL='https://pypi.org/simple/'

# Install Yolo Depend, cannot install with root
#RUN pip install pycuda==2025.1.1 --index-url https://pypi.jetson-ai-lab.io/jp6/cu126
#RUN pip install ultralytics==8.3.170 --index-url https://pypi.jetson-ai-lab.io/jp6/cu126
#RUN pip install opencv-python==4.12.0.88 --index-url https://pypi.jetson-ai-lab.io/jp6/cu126
#RUN pip install numpy==1.26.4 --index-url https://pypi.jetson-ai-lab.io/jp6/cu126


#RUN sudo apt-get update
#RUN sudo apt install python3-serial
#RUN pip install Jetson.GPIO
#RUN pip install onnxslim onnxruntime --index-url https://pypi.jetson-ai-lab.io/jp6/cu126
#RUN pip install onnx==1.17.0 --index-url https://pypi.jetson-ai-lab.io/jp6/cu126
#RUN pip install onnxruntime-gpu --index-url https://pypi.jetson-ai-lab.io/jp6/cu126

RUN echo "export PATH=$HOME/.local/bin:$PATH" >> /home/work/.bashrc

# Default container startup command (modify as needed)
# CMD ["bash"]


####GR00T setup
RUN sudo apt remove -y python3-sympy
RUN sudo pip3 uninstall -y opencv-contrib-python

# Set to get precompiled jetson wheels
RUN export PIP_INDEX_URL=https://pypi.jetson-ai-lab.io/jp6/cu126 && \
    export PIP_TRUSTED_HOST=pypi.jetson-ai-lab.io && \
    pip3 install --upgrade pip setuptools && \
    pip3 install -e .[orin]

# Build and install decord
RUN git clone https://git.ffmpeg.org/ffmpeg.git && \
    cd ffmpeg && \
    git checkout n4.4.2 && \
    ./configure --enable-shared --enable-pic --prefix=/usr && \
    sudo make -j$(nproc) && \
    sudo make install && \
    rm -rf ffmpeg

RUN git clone --recursive https://github.com/dmlc/decord && \
    cd decord && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make && \
    cd ../python && \
    python3 setup.py install --user && \
    rm -rf decord

# Set decord library path environment variable
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/work/.local/decord/


RUN sudo pip3 uninstall -y opencv-python opencv-python-headless
RUN pip3 install --no-cache-dir opencv-python==4.11.0.86
RUN pip3 install --no-cache-dir opencv-python-headless==4.11.0.86
RUN pip3 install --force-reinstall numpy==1.26.4
RUN pip3 install pyrealsense2

RUN pip3 install jinja2==3.1.0
RUN sudo apt update && sudo apt install byobu -y

CMD ["byobu"]
# ENTRYPOINT ["/entrypoint.sh", "byobu"]

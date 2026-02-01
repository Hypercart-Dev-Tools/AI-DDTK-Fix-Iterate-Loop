# ============================================================
# AI-DDTK Installation Test Container
# ============================================================
#
# PURPOSE:
#   Tests the full install flow in a clean environment.
#   Simulates a fresh user machine with git, bash, and zsh.
#
# USAGE:
#   cd AI-DDTK
#   docker build -t ai-ddtk-test -f test/Dockerfile .
#   docker run --rm ai-ddtk-test
#
# FOR LLM AGENTS:
#   - This tests install.sh in isolation
#   - It does NOT test WPCC functionality (no Node.js by default)
#   - Add Node.js to test full WPCC if needed
#   - Exit code 0 = all tests passed
#
# ============================================================

FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    bash \
    zsh \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (optional, for full testing)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Create test user (simulates real user environment)
RUN useradd -m -s /bin/bash testuser
USER testuser
WORKDIR /home/testuser

# Create bin directory (standard location)
RUN mkdir -p /home/testuser/bin

# Copy the toolkit
COPY --chown=testuser:testuser . /home/testuser/bin/ai-ddtk

# Make scripts executable
RUN chmod +x /home/testuser/bin/ai-ddtk/install.sh \
    /home/testuser/bin/ai-ddtk/bin/wpcc

# Create .bashrc and .zshrc
RUN touch /home/testuser/.bashrc /home/testuser/.zshrc

# Run tests
COPY --chown=testuser:testuser test/test-install.sh /home/testuser/test-install.sh
RUN chmod +x /home/testuser/test-install.sh

# Default command runs the test suite
CMD ["/home/testuser/test-install.sh"]


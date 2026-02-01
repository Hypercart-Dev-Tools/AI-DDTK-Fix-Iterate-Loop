# WP Code Check - CI Test Environment (Ubuntu)
#
# This Dockerfile creates an environment identical to GitHub Actions
# for testing the test suite in a true Linux CI environment.
#
# Usage:
#   docker build -t wp-code-check-test -f tests/Dockerfile .
#   docker run --rm wp-code-check-test
#

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV CI=true
ENV GITHUB_ACTIONS=true
ENV TERM=dumb

# Install dependencies (matching GitHub Actions environment)
RUN apt-get update && apt-get install -y \
    bash \
    jq \
    perl \
    grep \
    sed \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /workspace

# Copy the entire dist directory
COPY . /workspace/

# Make scripts executable
RUN chmod +x /workspace/bin/check-performance.sh \
    && chmod +x /workspace/bin/pattern-library-manager.sh \
    && chmod +x /workspace/tests/run-fixture-tests.sh \
    && chmod +x /workspace/tests/run-tests-ci-mode.sh

# Verify environment
RUN echo "=== Environment Check ===" \
    && echo "OS: $(cat /etc/os-release | grep PRETTY_NAME)" \
    && echo "Bash: $(bash --version | head -1)" \
    && echo "jq: $(jq --version)" \
    && echo "perl: $(perl --version | grep 'This is perl')" \
    && echo "TTY available: $([ -w /dev/tty ] && echo 'yes' || echo 'no')" \
    && echo "CI: $CI" \
    && echo "GITHUB_ACTIONS: $GITHUB_ACTIONS"

# Default command: run tests
CMD ["bash", "-c", "cd /workspace && ./tests/run-fixture-tests.sh"]


#!/usr/bin/env bash
#
# WP Code Check - Bash/Zsh Completion Script
# Version: 1.0.0
#
# Installation:
#   # For bash
#   echo "source ~/WP-Code-Check/dist/bin/wp-check-completion.bash" >> ~/.bashrc
#   source ~/.bashrc
#
#   # For zsh
#   echo "source ~/WP-Code-Check/dist/bin/wp-check-completion.bash" >> ~/.zshrc
#   source ~/.zshrc
#
# Usage:
#   wp-check --<TAB>        # Shows all options
#   wp-check --format <TAB> # Shows format options (text, json)
#

# Bash completion function
_wp_check_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  
  # All available options
  opts="--project --paths --format --strict --verbose --no-log --no-context --context-lines --severity-config --generate-baseline --baseline --ignore-baseline --skip-clone-detection --help"
  
  # Context-aware completion based on previous argument
  case "${prev}" in
    --format)
      # Format options
      COMPREPLY=( $(compgen -W "text json" -- ${cur}) )
      return 0
      ;;
    --paths|--baseline|--severity-config)
      # Directory/file completion
      COMPREPLY=( $(compgen -d -- ${cur}) )
      return 0
      ;;
    --project)
      # Template completion - list available templates
      local templates=""
      local template_dir=""
      
      # Try to find TEMPLATES directory
      # Check common locations relative to the script
      for dir in "$HOME/WP-Code-Check/dist/TEMPLATES" "$HOME/wp-code-check/dist/TEMPLATES" "./dist/TEMPLATES" "../TEMPLATES"; do
        if [ -d "$dir" ]; then
          template_dir="$dir"
          break
        fi
      done
      
      if [ -n "$template_dir" ]; then
        # List template files without .txt extension
        templates=$(find "$template_dir" -maxdepth 1 -name "*.txt" ! -name "_*" -exec basename {} .txt \; 2>/dev/null)
        COMPREPLY=( $(compgen -W "$templates" -- ${cur}) )
      fi
      return 0
      ;;
    --context-lines)
      # Numeric completion (suggest common values)
      COMPREPLY=( $(compgen -W "1 2 3 5 10" -- ${cur}) )
      return 0
      ;;
    *)
      ;;
  esac
  
  # Default: complete with available options
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

# Zsh completion function (compatible with bash completion)
_wp_check_completion_zsh() {
  local -a opts
  local cur prev
  
  cur="${words[CURRENT]}"
  prev="${words[CURRENT-1]}"
  
  # All available options
  opts=(
    '--project:Load configuration from template'
    '--paths:Paths to scan'
    '--format:Output format (text or json)'
    '--strict:Fail on warnings'
    '--verbose:Show all matches'
    '--no-log:Disable logging'
    '--no-context:Disable context lines'
    '--context-lines:Number of context lines'
    '--severity-config:Custom severity config file'
    '--generate-baseline:Generate baseline file'
    '--baseline:Custom baseline file path'
    '--ignore-baseline:Ignore baseline file'
    '--skip-clone-detection:Skip clone detection'
    '--help:Show help message'
  )
  
  case "${prev}" in
    --format)
      _values 'format' 'text' 'json'
      return 0
      ;;
    --paths|--baseline|--severity-config)
      _files -/
      return 0
      ;;
    --project)
      local template_dir=""
      for dir in "$HOME/WP-Code-Check/dist/TEMPLATES" "$HOME/wp-code-check/dist/TEMPLATES" "./dist/TEMPLATES" "../TEMPLATES"; do
        if [ -d "$dir" ]; then
          template_dir="$dir"
          break
        fi
      done
      
      if [ -n "$template_dir" ]; then
        local -a templates
        templates=(${(f)"$(find "$template_dir" -maxdepth 1 -name "*.txt" ! -name "_*" -exec basename {} .txt \; 2>/dev/null)"})
        _values 'template' $templates
      fi
      return 0
      ;;
    --context-lines)
      _values 'lines' '1' '2' '3' '5' '10'
      return 0
      ;;
  esac
  
  _describe 'option' opts
}

# Register completion based on shell type
if [ -n "$BASH_VERSION" ]; then
  # Bash completion
  complete -F _wp_check_completion wp-check
  complete -F _wp_check_completion check-performance.sh
elif [ -n "$ZSH_VERSION" ]; then
  # Zsh completion
  autoload -U compinit && compinit
  compdef _wp_check_completion_zsh wp-check
  compdef _wp_check_completion_zsh check-performance.sh
fi

# Success message (only show once when sourced)
if [ -z "$WP_CHECK_COMPLETION_LOADED" ]; then
  export WP_CHECK_COMPLETION_LOADED=1
  echo "✓ WP Code Check tab completion loaded"
  echo "  Try: wp-check --<TAB>"
fi


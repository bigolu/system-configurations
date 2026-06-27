if [ -f ~/.config/default-shells/login-config.sh ]; then
  emulate sh -c '. ~/.config/default-shells/login-config.sh'
  emulate zsh
fi

INSTALL_FILES := ackrc aptitude/config autojump $(wildcard bazaar/plugins/*) $(filter-out bazaar/plugins,$(wildcard bazaar/*)) $(wildcard byobu/*) byobu/.screenrc gemrc gitconfig gitignore.global gvimrc hgrc irbrc lib oh-my-zsh pdbrc pentadactyl pentadactylrc railsrc screenrc screenrc.common subversion/servers terminfo vim vimrc vimpagerrc Xresources xsessionrc
# zshrc needs to get installed after submodules have been initialized
INSTALL_FILES_AFTER_SM := zlogin zshenv zshrc

default: migrate install

install: install_files init_submodules install_files_after_sm

# Migrate existing dotfiles setup
migrate: .stamps .stamps/migrate_byobu.2 .stamps/dangling.1
.stamps/migrate_byobu.2:
	@# .local/share/byobu is handled independently (preferred), only use ~/.byobu
	$(RM) -r ~/.local/share/byobu
	$(RM) ~/.byobu/keybindings ~/.byobu/profile ~/.byobu/profile.tmux ~/.byobu/status ~/.byobu/statusrc
	$(RM) .stamps/migrate_byobu.*
	touch $@
.stamps/dangling.1:
	for i in ~/.byobu ~/.byoburc ~/.sh ~/.bin ~/.vimperator ~/.vimperatorrc ~/.gitignore ; do \
		test -h "$$i" && { test -e "$$i" || $(RM) "$$i" ; } || true ; \
	done
	touch $@
.stamps:
	mkdir -p .stamps

# Target to install a copy of .dotfiles, where Git is not available
# (e.g. distributed with rsync)
install_checkout: install_files install_files_after_sm

# Handle Git submodules
init_submodules: sync_submodules update_submodules
update_submodules:
	# Requires e.g. git 1.7.5.4
	git submodule update --init --quiet
	# Simulate `--recursive`, but not for vim/bundle/command-t:
	# (https://github.com/wincent/Command-T/pull/23)
	cd vim/bundle/operator-replace && git submodule update --init --quiet
	cd vim/bundle/operator-user && git submodule update --init --quiet
sync_submodules:
	git submodule sync --quiet

ALL_FILES := $(INSTALL_FILES) $(INSTALL_FILES_AFTER_SM)

.PHONY: $(ALL_FILES)

install_files: $(addprefix ~/.,$(INSTALL_FILES))
install_files_after_sm: $(addprefix ~/.,$(INSTALL_FILES_AFTER_SM))

~/.% ~/.local/share/%: %
	@test -h $@ \
		|| { test -f $@ && echo "Skipping existing target (file): $@"; } \
		|| { test -d $@ && echo "Skipping existing target (dir): $@"; } \
		|| { mkdir -p $(shell dirname $@) && ln -sfn ${CURDIR}/$< $@ ; }

diff_files: $(ALL_FILES)
	@for i in $^ ; do \
		test -h "$$HOME/.$$i" && continue; \
		echo ===== $$HOME/.$$i $(CURDIR)/$$i ================ ; \
		ls -lh "$$HOME/.$$i" "$(CURDIR)/$$i" ; \
		if cmp "$$HOME/.$$i" "$(CURDIR)/$$i" ; then \
			echo "Same contents." ; \
		else \
		  diff -u "$$HOME/.$$i" "$(CURDIR)/$$i" ; \
		fi ; \
		printf "Replace regular file/dir ($$HOME/.$$i) with symlink? (y/n) " ; \
		read yn ; \
		if [ "x$$yn" = xy ]; then \
			command rm -rf "$$HOME/.$$i" ; \
			ln -sfn "$(CURDIR)/$$i" "$$HOME/.$$i" ; \
		fi \
	done

setup_full: setup_ppa install_programs install_zsh setup_zsh

setup_ppa:
	# TODO: make it work with missing apt-add-repository (Debian Squeeze)
	sudo apt-add-repository ppa:git-core/ppa

install_programs:
	sudo apt-get update
	sudo apt-get install aptitude
	sudo aptitude install console-terminus git rake vim-gnome xfonts-terminus xfonts-terminus-oblique exuberant-ctags
	# extra
	sudo aptitude install ttf-mscorefonts-installer
install_zsh:
	sudo aptitude install zsh
install_commandt_module:
	cd ~/.dotfiles/vim/bundle/command-t && \
		rake make


install_programs_rpm: install_zsh_rpm
	sudo yum install git rubygem-rake ctags
install_zsh_rpm:
	sudo yum install zsh

ZSH_PATH := /bin/zsh
ifneq ($(wildcard /usr/bin/zsh),)
	ZSH_PATH := /usr/bin/zsh
endif
ifneq ($(wildcard /usr/local/bin/zsh),)
	ZSH_PATH := /usr/local/bin/zsh
endif

setup_sudo:
	@user_file=/etc/sudoers.d/$$USER ; \
	if [ -e $$user_file ] ; then \
		echo "$$user_file exists already." ; exit 1 ; \
	fi ; \
	printf '# sudo config for %s\nDefaults:%s !tty_tickets,timestamp_timeout=60\n' $$USER $$USER | sudo tee $$user_file.tmp > /dev/null \
		&& sudo chmod 440 $$user_file.tmp \
		&& sudo visudo -c -f $$user_file.tmp \
		&& sudo mv $$user_file.tmp $$user_file

setup_zsh:
	# changing shell to zsh, if $$ZSH is empty (set by oh-my-zsh/dotfiles)
	[ "$(shell getent passwd $$USER | cut -f7 -d:)" != "${ZSH_PATH}" -o "$(shell zsh -i -c env|grep '^ZSH=')" != "" ] && chsh -s ${ZSH_PATH}

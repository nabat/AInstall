###############################################
Autoinstaller for ABillS based on plugin system
ver. 0.1
Feel free to make bugreports

Plugins are structured as plugins/Distributive_VersionArch

================================================
Plugin Format
================================================
<code>
#TAG_NAME action

OS tag OS_NAME OS_VERSION
  #OS freebsd 10

COMMENTS tag coments for plugin

  #COMMENTS [Freebsd comments]

#M module configure tag
  #module_tag [item_name]:[item describe]:[command]

as command you can use shell command like 
  pkg install www 
or shell function
  shell_function

pre_install  execute function before install modules

post_install execute function after full installation


#---------------#
#               #
# Pre install   #
#               #
#---------------#
        |
#---------------#
#               #
#   install     #
#   programs    #
#---------------#
        |
#---------------#
#               #
# Post install  #
#               #
#---------------#
        |
#---------------#
# Configuration #
#      and      #
#    startup    #
#    Section    #
# misc/autoconf #
#---------------#
       |
#---------------#
#               # 
# Final result  #
#---------------#
</code>


Autoinstaller for ABillS based on plugin system
===============================================

ver. 0.1
Feel free to make bugreports

Plugins are structured as plugins/Distributive_VersionArch

Plugin Format
-------------

<table>
  <tr>
    <td>
      #OS OS_NAME OS_VERSION
    </td>
    <td>
      #OS freebsd 10
    </td>
  </tr>
  <tr>
    <td>
      #COMMENTS comments for plugin
    </td>
    <td>
      #COMMENTS CentOS comment
    </td>
  </tr>
  <tr>
    <td>
      #M [module_name]:[module describe]:[command]
    </td>
    <td>
      #M mysql:MySQL:_install_mysql
    </td>
  </tr>

</table>

As command you can use shell command like 
  <b>pkg install www</b> 
or shell function:
  <b>shell_function</b>

Inside plugin you can use these functions to execute custom commands.
<table>
  <tr>
    <td>
      pre_install()
    </td>
    <td>
      executes before installing modules
    </td>
  </tr>
  <tr>
    <td>
      post_install()
    </td>
    <td>
       executes after full installation (before autoconf)
    </td>
  </tr>  
</table> 


Plugin execution
----------------
<table>
  <tr>
    Pre install 
  </tr>
  <tr>
    install programs
  </tr>
  <tr>
    Post install
  </tr>
  <tr>
    misc/autoconf 
  </tr>
  <tr>
    Final result
  </tr>
</table>

Installer uses autoconf for module configuration and defining system startup.
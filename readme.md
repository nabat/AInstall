
Installer for ABillS based on plugin system
===============================================

ver. 5.24

Installing:
  * ABillS
  * MySQL
  * FreeRadius
  * Apache
  * Accel-PPPoE
  * Flow-tools
  * Fsbackup
  * MRTG

Support OS:

 - centos_7_x64
 - debian_8_x64
 - debian_9_x64
 - debian_10_x64
 - freebsd_10_x64
 - freebsd_10_x86
 - freebsd_11_x64
 - ubuntu_14_x64
 - ubuntu_16_x64
 - ubuntu_18_x64
 - ubuntu_19_x64

Plugins are structured as plugins/Distributive_Version_Arch

As of version 5.05 it can guess your system.
If guessed wrong, use ''-p'' key
  
 <code>
  # ./install.sh -p centos_7_x64
 </code>   
   
If you want avoid tmux session use ''--in_tmux'' key
    
<code>
  # ./install.sh --in_tmux
</code>

If you want to install custom version use ''--install-version'' key

<code>
./install.sh --install-version 78.25 
 </code>
  
Plugin Format
-------------

<table>
  <tr>
    <td>
      <b>Section</b>
    </td>
    <td>
      <b>Example</b>
    </td>
  </tr>
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


Plugin execution flow
----------------
<table>
  <tr><td>
    Pre install 
  </td></tr>
  <tr><td>
    Install programs
  </td></tr>
  <tr><td>
    Post install
  </td></tr>
  <tr><td>
    Run misc/autoconf 
  </td></tr>
  <tr><td>
    Show result
  </td></tr>
</table>

Installer uses <b>autoconf</b> for module configuration and defining system startup.

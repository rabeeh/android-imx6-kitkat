function help()
{
cat <<EOF
Invoke ". and_patch.sh" from your shell to add following functions to your environment:
-- c_gotop:	Changes directory to the top of the tree 
-- c_patch:	Recover working tree to base version and then applying FSL android patch
EOF
}
function c_gotop()
{
    T=$(c_gettop)
    if [ "$T" ]; then
	cd "$T"
    else
	echo "Error! Couldn\'t locate top dir of repo tree."
    fi
}

function c_gettop()
{
    local TOPFILE=build/core/main.mk
    if [ -f $TOPFILE ] ; then
        echo $PWD
    else
	# Save current dir to HERE and later restore it
	local HERE=$PWD
	T=
	while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
	    cd .. > /dev/null
	    T=$PWD
	done 
	# Still keep current dir
	cd $HERE > /dev/null
	if [ -f "$T/$TOPFILE" ]; then
	    echo "$T"
	fi
    fi
}

function is_git_dir()
{
    local GIT_HEAD=HEAD
    local GIT_CONFIG=config
    local GIT_OBJECTS=objects
    local D="$1"

    if [ ! -d "$D" ]; then
	echo false
    else
        if [ \( -e "$D/$GIT_HEAD" \) -a \( -e "$D/$GIT_CONFIG" \) -a \( -e "$D/$GIT_OBJECTS" \) ]; then
            echo true
        else
	    echo false
        fi
    fi
}

function is_branch_exist
{
    local D="$1"
    local B="$2"
    local B_found
    local HERE

    if [ \( ! -d "$D" \) -o \( -z "$B" \) ]; then
	echo false
	return
    fi

    HERE=$PWD
    cd "$D" > /dev/null

    # Check branch
    git branch 2>&1 > /dev/null
    if [ $? -ne 0 ]; then
        echo false
	cd $HERE > /dev/null
	return
    fi
    B_found=`git branch | grep -w "$B"`
    if [ -z "$B_found" ]; then
	echo false
    else
        echo true 
    fi

    cd $HERE > /dev/null
    return
}

function parse_manifest_file
{
    local D=$1

    if [ ! -r "$D" ]; then
        return
    fi

    awk '
	BEGIN { RS=">"; def_rev=""; cnt=0; abort=0; error_code=""; suspect_error=0; split("",projects); }
	/<default/ {
                for(x=1; x<=NF; x+=1) {
		    if( $x ~ /^revision=/ ) {
			split( $x, array, "=");
			def_rev = array[2];
			gsub(/\"/, "", def_rev);
		    }
                }
		if ( def_rev == "" ) {
		    abort=1;
		    error_code="No default revision";
		    exit 1;
		}
            } 
	/<\/project/ {
		if ( suspect_error != 0 ) { suspect_error = 0; }
		}
	/<project/ {
		if ( suspect_error != 0 ) {
		    abort=1;	
		    error_code="Not valid project line - no valid ending";
		    exit 1;
		}
		if ( $0 !~ /\/$/ ) {
		    suspect_error=1;
		}
                for(x=1; x<=NF; x+=1) {
		    if( $x ~ /^path=/ ) {
			split( $x, array, "=");
			path = array[2];
			gsub(/\"/, "", path);
		    }
		    if( $x ~ /^name=/ ) {
			split( $x, array, "=");
			name = array[2];
			gsub(/\"/, "", name);
		    }
		    if( $x ~ /^revision=/ ) {
			split( $x, array, "=");
			revision = array[2];
			gsub(/\"/, "", revision);
		    }
                }
		if ( revision == "" ) { revision = def_rev; }
		if ( ( path == "" ) || ( name == "" ) || ( revision == "" ) ) {
		    abort=1;
		    error_code="Not valid project line - path/name/rev is invalid";
		    exit 1;
		}
		cnt+=1;
		projects[cnt,1]=path;
		projects[cnt,2]=name;
		projects[cnt,3]=revision;
		path=""; name=""; revision="";
	    }
	END { 
		if(abort != 0) { printf "ERROR! %s", error_code; exit 1;}
		for(x=1; x<=cnt; x+=1) {
		    printf "%-30s\t%-30s\t%-20s\n", projects[x,1], projects[x,2], projects[x,3] ;
		}
            }
    ' "$D"
}

function c_list_all_projects
{
    local D=$1
    local parse_result

    if [ \( -z "$D" \) -o \( ! -r "$D" \) ]; then
        echo "Error! Must call with a valid manifest file"
        return
    fi
    
    parse_result=$(parse_manifest_file "$D")

    echo "$parse_result"
}

# Recover base version of Android and apply FSL android patch   
function c_patch
{
    local TOP=$(c_gettop)
    local D=$1
    local patch_branch=$2
    local D_ABS
    local basefile
    local cnt=0
    local parse
    local lines
    local types
    local commits
    local paths
    local names
    local git_dirs
    local patch_git_dirs
    local warning_cnt=0
    local warnings
    local warning_branch_cnt=0
    local warnings_branch
    local x
    local index
    local patch_files
    local usage="usage: c_patch patchdir patch_branch"

    if [ ! -d "$TOP" ] ; then
        echo "Error! Can't locate top dir of repo tree."
        return
    fi

    if [ \( -z "$D" \) -o \( ! -d "$D" \) ]; then
	echo "Error! Must call with a valid patch dir" 
	echo "$usage"
	return
    fi
    # convert patch dir to absolute path
    HERE=$PWD
    cd "$D" > /dev/null
    D_ABS=`pwd -P`
    D="$D_ABS"
    cd "$HERE" > /dev/null

    basefile="$D/baseversion"
    if [ ! -r "$basefile" ]; then
	echo "Error! Can't read base file - $basefile"
	return
    fi
    #if [ \( ! -d $TOP/kernel_imx \) -o \( $(is_git_dir $TOP/kernel_imx/.git) != "true" \) ]; then
#	echo "Error! You need setup kernel git $TOP/kernel_imx by clone from kernel.org before doing others"
 #       return
  #  fi  
    if [ -z "$patch_branch" ]; then
	echo "Error! You must specify a new branch name on which FSL patch will be put"
	echo "$usage"
	return
    fi

    # Get project counts
    parse=`cat $basefile`
    cnt=`echo "$parse" | wc -l`
    if [ $cnt -eq 0 ]; then
	echo "Error! No any project in base file $basefile"
	return
    fi

    # Parse basefile 
    echo "Parsing basefile $basefile..."
    x=1
    while [ $x -le $cnt ] ; do
        # Get each line and parse it to TYPE/COMMIT_ID/PATH/NAME
	lines[$x]=`echo "$parse" | awk NR==$x`
	types[$x]=`echo "${lines[$x]}" | awk '{print $2}'` 
	commits[$x]=`echo "${lines[$x]}" | awk '{print $3}'` 
	paths[$x]=`echo "${lines[$x]}" | awk '{print $4}'` 
	names[$x]=`echo "${lines[$x]}" | awk '{print $5}'` 

	# Any above fields should NOT be empty
	if [ \( -z ${types[$x]} \) -o \
	     \( -z ${commits[$x]} \) -o \
	     \( -z ${paths[$x]} \) -o \
	     \( -z ${names[$x]} \) ]; then
	    echo "Error! Something wrong at line $x of file $basefile. Stop"
	    return
	fi

	git_dirs[$x]="$TOP/${paths[$x]}"
        patch_git_dirs[$x]="$D/${names[$x]}.git"

	# Special handling for kernel_imx project. This project is marked as "NEW" type in basefile but
	# we don't provide whole bare git for it (not like other NEW projects). Instead, base code of kernel_imx
	# need be manually cloned from kernel.org and then apply all FSL patches. So we modify it's type to
	# "CHANGE" on the fly
	if [ \( ${types[$x]} = "NEW" \) -a \( ${names[$x]} = "kernel_imx" \) ]; then
	    types[$x]="CHANGE"
	fi

	x=$(($x+1))
    done

    # Check working tree and patch dir
    echo "Check work tree and patch dir based on $basefile..."
    x=1
    warning_cnt=0
    warning_branch_cnt=0
    while [ $x -le $cnt ] ; do
	echo "Checking ${types[$x]} project - ${paths[$x]} ..."
	case "${types[$x]}" in
	NEW)
	    # Make sure the new git exist under patch dir as a bare git
 
#     if [ \( ! -d ${patch_git_dirs[$x]} \) -o \
#		\( $(is_git_dir ${patch_git_dirs[$x]}) != "true" \) ]; then
#		echo "Error! Can't find bare git under ${patch_git_dirs[$x]}. Stop"
#		return
#	    fi

	    # Make sure the base version exist in the bare git
	    # To be filled

	    # If the new git exist already in work tree, save the index and will prompt user later
	    if [ -d ${git_dirs[$x]} ]; then
		warning_cnt=$(($warning_cnt+1))
		warnings[$warning_cnt]=$x
	    fi

	    ;;
        KEEP|CHANGE)
            # Check git dir in current work tree
	    if [ ! -d ${git_dirs[$x]} ]; then
	        echo "Error! The git ${git_dirs[$x]} doesn't exist. Stop"
		return
	    fi
	    # Make sure base version exist in your gits
	    HERE=$PWD
	    cd "${git_dirs[$x]}" > /dev/null
	    git show --pretty=oneline "${commits[$x]}" > /dev/null
	    if [ $? -ne 0 ]; then
	        echo "Error! Base version commit ${commits[$x]} doesn't exist in git ${git_dirs[$x]}. Stop"
	        cd $HERE
	        return 
	    fi 
	    cd $HERE

	    # For CHANGE project, we will apply patch on patch branch. That branch should NOT exist at this time 
	    # Save the index and will prompt user later
	    if [ "${types[$x]}" = "CHANGE" ]; then
		if [ $(is_branch_exist ${git_dirs[$x]} $patch_branch) = "true" ]; then
		    warning_branch_cnt=$(($warning_branch_cnt+1))
		    warnings_branch[$warning_branch_cnt]=$x
		fi
	    fi
	    ;;
	*)
	    # Should NEVER be here
	    echo "Error! Wrong project type ${types[$x]} at line $x of basefile $basefile"
	    return
	    ;;
	esac

	x=$(($x+1))
    done

    # If those new gits exist in work repo already, prompt that they will be deleted firstly before loading from patch dir
    if [ $warning_cnt -gt 0 ] ; then
	echo "Warning: The following NEW gits exist already in your work tree and will be removed firstly."
	x=1
	while [ $x -le $warning_cnt ] ; do
	    echo "${paths[${warnings[$x]}]}"
	    x=$(($x+1))
	done
	echo -n "Continue? [yes/no]"
        read answer
	if [ \( "$answer" != yes \) -a \( "$answer" != y \) ]; then
	    echo "Exit without updating your repo tree."
	    return
	fi
    fi

    # If patch branch exist in work repo already, prompt that they will removed in force
    if [ $warning_branch_cnt -gt 0 ]; then
	echo "Warning: The patch branch $patch_branch you specified already exist in below gits and will be deleted."
	x=1
	while [ $x -le $warning_branch_cnt ] ; do
	    echo "${paths[${warnings_branch[$x]}]}"
	    x=$(($x+1))
	done
	echo -n "Continue? [yes/no]"
        read answer
	if [ \( "$answer" != yes \) -a \( "$answer" != y \) ]; then
	    echo "Exit without deleting branch."
	    return
	fi
	# Delete existing patch branch
	x=1
	while [ $x -le $warning_branch_cnt ] ; do
	    index=${warnings_branch[$x]} 
	    echo "Deleting branch $patch_branch from ${paths[$index]}"
	    HERE=$PWD
	    cd ${git_dirs[$index]} > /dev/null
	    # switch to other HEAD so that we can remove branch in case current HEAD is on it
            git checkout -q -f "${commits[$index]}" > /dev/null
	    git branch -D "$patch_branch" > /dev/null
	    if [ $? -ne 0 ]; then
		echo "Error! Fail to delete branch $patch_branch from ${git_dirs[$index]}. Stop"
		cd $HERE
		return
	    fi
	    cd $HERE > /dev/null
	    x=$(($x+1))
	done
    fi

    # Load NEW gits
    echo "Load new gits created by FSL..."
    x=1
    HERE=$PWD
    while [ $x -le $cnt ] ; do
	if [ ${types[$x]} = "NEW" ]; then
	    echo "Creating NEW gits - ${paths[$x]}"
	    # delete the git dir in case it exist 
	    rm -rf ${git_dirs[$x]} 2>&1 > /dev/null

      #For NEW project, we will do 1:git init project,2:touch a new dummy file for applying patch successfully;3:git add dummy file;4:git commit    
      #1: git init new git
	    mkdir -p "${git_dirs[$x]}" > /dev/null
            cd "${git_dirs[$x]}" > /dev/null
	    git init > /dev/null
	    if [ $? -ne 0 ]; then
		    echo "Error! Fail to git init new git from ${git_dirs[$x]}"
		    return
	    fi

      #2: create a new dummy file	    
	    touch .dummy > /dev/null

      #3: git add the file	    
            git add .dummy > /dev/null

      #4: git commit
	    git commit -a -m "create dummy git" > /dev/null
	    if [ $? -ne 0 ]; then
		    echo "Error! Fail to git commit dummy to ${git_dirs[$x]}"
		    return
	    fi
	fi
	x=$(($x+1))
	cd $HERE > /dev/null
    done

    # Switch to base version for all NEW/CHANGE/KEEP gits
    echo "Switch all gits to base version ..."
    x=1
    while [ $x -le $cnt ] ; do
	HERE=$PWD
	cd ${git_dirs[$x]} > /dev/null
	echo "Switching base version for ${paths[$x]}"
	if [ \( ${types[$x]} = "CHANGE" \) -o \( ${types[$x]} = "NEW" \) ]; then
	    # For CHANGE/NEW project, create patch branch from specified commit or master(dummy)
	    # Throw out local change if any
            git clean -f -d -q > /dev/null
	    if [ ${types[$x]} = "CHANGE" ]; then
          git checkout -q -f -b $patch_branch "${commits[$x]}" > /dev/null
	    else
            #For NEW project, create patch branch from master directly , not use commit id indicated on baseversion
          git checkout -q -f -b $patch_branch master > /dev/null
      fi
      if [ $? -ne 0 ]; then
	        echo "Error! Fail to checkout commit ${commits[$x]} from ${git_dirs[$x]}"
	        cd $HERE > /dev/null
	        return
	    fi
	else
	    # For KEEP project, directly checkout from specified commit without forking branch
	    git checkout -q -f "${commits[$x]}" > /dev/null
	    if [ $? -ne 0 ]; then
	        echo "Error! Fail to checkout commit ${commits[$x]} from ${git_dirs[$x]}"
	        cd $HERE > /dev/null
	        return
	    fi
	fi
	cd $HERE > /dev/null
	x=$(($x+1))
    done

    # Verify all patches can be done before we actually patch
#   echo "Verify patches ..."
#   x=1
#   while [ $x -le $cnt ] ; do
#if [ ${types[$x]} = "CHANGE" ]; then 
#    HERE=$PWD
#    cd ${git_dirs[$x]} > /dev/null
#    echo "Verify patch for ${paths[$x]}"
#    patch_files=`ls ${patch_git_dirs[$x]}/*.patch | tr '\n' ' '`
#           if [ -z "$patch_files" ]; then
#	echo "Error! No patch was found under ${patch_git_dirs[$x]}. Stop"
#        cd $HERE
#	return
#    fi
#    git apply --check $patch_files > /dev/null
#    if [ $? -ne 0 ]; then
#	echo "Error! Can't patch from ${patch_git_dirs[$x]} to ${git_dirs[$x]}. Stop"
#        cd $HERE
#	return
#    fi
#    cd $HERE > /dev/null
#fi
#x=$(($x+1))
#   done

    # Apply FSL patches to CHANGE/NEW project
    echo "Applying patches ..."
    x=1
    while [ $x -le $cnt ] ; do
	if [ \( ${types[$x]} = "CHANGE" \) -o \( ${types[$x]} = "NEW" \) ]; then 
	    HERE=$PWD
	    cd ${git_dirs[$x]} > /dev/null
	    echo "Applying patch to ${paths[$x]}"
	    unset LS_OPTIONS
	    (cd ${patch_git_dirs[$x]}; ls *.patch) > ${patch_git_dirs[$x]}/series
	    git quiltimport --patches ${patch_git_dirs[$x]} > /dev/null
	if [ $? -ne 0 ]; then
		echo "Error! Fail to apply patch from ${patch_git_dirs[$x]} to ${git_dirs[$x]}. Stop"
	        cd $HERE
		return
	    fi
	    cd $HERE > /dev/null
	fi
	x=$(($x+1))
    done

    echo "*************************************************************"
    echo "Success: Now you can build android code for FSL i.MX platform"
    echo "*************************************************************"
}

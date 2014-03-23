#!/usr/bin/env bash
function getusers {
  echo "" > svntogit/authors.txt
  echo "svntogit/authors.txt file created"
  authors=$(svn log -q $repo | grep -e '^r' | awk 'BEGIN { FS = "|" } ; { print $2 }' | sort | uniq)
  for author in ${authors}; do
    echo "${author} = ${author} <${author}@${host}.com>" >> svntogit/authors.txt;
  done
  echo "svntogit/authors.txt file written"
}

function getinfo {
  read -p "Please enter the default email host and press enter: " host
  read -p "Please enter the project name and press enter: " name
  # Get repo info
  read -p "Please enter the svn repo and press enter (one level up from trunk): " repo
  # get git info
  read -p "Please enter the git repo and press enter:" gitrepo
  # get names of folders in svn
  read -p "Please enter the tags folder (or leave blank to default to \"tags\") and press enter: " tags
  read -p "Please enter the branches folder (or leave blank to default to \"branches\") and press enter: " branches
  read -p "Please enter the trunk folder (or leave blank to default to \"trunk\") and press enter: " trunk
}

mkdir -p svntogit
echo "made directory svntogit"

# Gather info
getinfo
# Create user file
getusers

# Create script in case author not found
echo "#!/usr/bin/env bash
echo \"\$1 = \$1 <\$1@${host}.com>\";" > svntogit/svn-unknown-author.sh
echo "svntogit/svn-unknown-author.sh file written"
chmod 755 svntogit/svn-unknown-author.sh

# Execute git svn transfer
git svn clone --tags ${tags:=tags} --trunk ${trunk:=trunk} --branches ${branches:=branches} --authors-prog=svntogit/svn-unknown-author.sh --no-metadata -A svntogit/authors.txt $repo $name-temp

# Create branches and tags
cd $name-temp
for i in `git branch -r`
do
  echo $i
  if [[ "$i" == tags/* && "$i" != *@* ]] #Is a tag
  then
    echo creating tag: ${i:5}
    git checkout -b tag_${i:5} remotes/$i
    git checkout master
    git tag ${i:5} tag_${i:5}
    git branch -D tag_${i:5}
  elif [[ "$i" != *@* && "$i" != trunk ]]
  then
    echo creating branch: $i
    git checkout -b $i remotes/$i
  fi
done

# Create a clean repo locally
cd ..
git clone $name-temp $name-git
cd $name-git

# import all branches from svn
git branch -a | grep -v HEAD | perl -ne 'chomp($_); s|^\*?\s*||; if (m|(.+)/(.+)| && not $d{$2}) {print qq(git branch --track $2 $1/$2\n)} else {$d{$_}=1}' | csh -xfs

#push information into gitrepo
git remote rm origin
git remote add origin $gitrepo
git push -u origin --all
git push origin --tags
git checkout master

#cleanup
cd ..
rm -rf $name-temp
rm -rf svntogit

status=`git status`
if [[ $status =~ "source/_posts" || $status =~ "themes/mynext" ]]
then
  echo 'there you go'
  git add source/_posts
  git add themes/mynext
  echo 'commiting...'
  git commit -m 'auto update submodule hash'
  echo 'Push rightnow? Type 'n' to stop, type any to continue'
    read reply leftover
    case $reply in
      y* | Y*)
      echo 'pushing...'
      git push
      esac
else
  echo 'no any submodule change'
fi
submodules=(
  "source/_posts" "themes/mynext" "themes/mycactus"
)
isAnySubmoduleChange=false

# search submodule changes
# and sync commit
for submodule in ${submodules[*]}; do
  status=$(git status)
  if [[ $status =~ "$submodule" ]]; then
    commit=$(cd "$submodule" && git log -1 --pretty=format:"%s")
    echo "submodule $submodule last commit: $commit"

    echo "sync commit..."
    git add "$submodule"
    git commit -m "$commit"

    # mark change
    isAnySubmoduleChange=true
  fi
done

# push commit
if [ "$isAnySubmoduleChange" = true ]; then
  echo 'push rightnow? type 'n' to stop, type any to continue'
  read reply leftover
  case $reply in
  n* | N*)
    echo 'return'
    ;;
  *)
    echo 'pushing...'
    git push
    ;;
  esac
fi

url=$(git remote get-url origin)
cd public
git init
git config user.name "CI"
git config user.email "ci@evilmouth.net"
git remote add secure-origin "$url"
git checkout -b gh-pages
git add .
git commit -m "Updated docs"
git push --force secure-origin gh-pages
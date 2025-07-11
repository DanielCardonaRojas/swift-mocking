# Publishes docc documentation of swift package using swift-docc-plugin
# NOTE: All archives will be generated but only one will be visible as per current limitations in docc
# Requires the creation of orphan branch gh-pages and tweaking settings to publish from "gh-pages/docs"
set -e
BASE_PATH=/swift-mocking/docs
SELECTED_TARGET=MockableTypes
TARGETS="MockableTypes" # List of all targets/modules in swift package
DOC_REF=$(git describe --tags --abbrev=0 || git rev-parse --abbrev-ref HEAD)
WORKTREE_DIR=.worktrees/docs

# Check if the current branch is gh-pages
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "gh-pages" ]; then
	echo "Error: This script should not be run from the 'gh-pages' branch in the main repository."
	echo "Please switch to a development branch (e.g., 'main' or 'develop') and try again."
	exit 1
fi

git worktree prune
git fetch

# Check if gh-pages branch exists, if not, create it as an orphan branch
if ! git show-ref --verify --quiet refs/heads/gh-pages; then
	if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
		echo "Local gh-pages branch not found, but remote origin/gh-pages exists. Checking out remote branch."
		git checkout gh-pages # This will create a local gh-pages tracking origin/gh-pages
		git checkout -        # Return to previous branch
	else
		echo "Creating orphan branch gh-pages"
		git checkout --orphan gh-pages
		git rm -rf .
		echo ".build/" >.gitignore
		echo ".swiftpm/" >>.gitignore
		echo "Package.resolved" >>.gitignore
		git add .gitignore
		git commit --allow-empty --no-verify -m "Initial gh-pages commit"
		git push --no-verify origin gh-pages
		git checkout - # Return to previous branch
	fi
fi

# Create worktree with gh-pages branch
if [ -d "$WORKTREE_DIR" ]; then
	echo "Worktree directory $WORKTREE_DIR already exists. Assuming it's a valid worktree."
else
	if git worktree add $WORKTREE_DIR gh-pages; then
		echo "Created docs worktree"
	else
		echo "Error: Failed to create worktree at $WORKTREE_DIR. Please check your git worktree setup."
		exit 1
	fi
fi

# Generate documentation
echo "Creating documentation for $DOC_REF"
for TARGET in $TARGETS; do
	ARCHIVE_DIR=$WORKTREE_DIR/$TARGET.doccarchive

	swift package --allow-writing-to-directory $ARCHIVE_DIR generate-documentation \
		--target $TARGET \
		--output-path $ARCHIVE_DIR \
		--disable-indexing \
		--transform-for-static-hosting
done

# Copy generated documentation
echo "Copying selected target documentation to gh-pages branch"
cp -a $WORKTREE_DIR/$SELECTED_TARGET.doccarchive/. $WORKTREE_DIR/docs

# Push gh-pages
echo "Uploading to gh-pages"
cd $WORKTREE_DIR
git add .
git commit --no-verify -m "Generated documentation for $DOC_REF"
git push --no-verify -f
cd ../../

# Remove worktree and prune
git worktree remove $WORKTREE_DIR
echo "Clean up complete. Documentation should be available at github"

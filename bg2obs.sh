#!/bin/bash
#----------------------------------------------------------------------------------
# This script runs Jonathan clark's bg2md.rb ruby script and formats the output
# to be useful in Obsidian. Find the script here: https://github.com/jgclark/BibleGateway-to-Markdown
#
# It needs to be run in the same directory as the 'bg2md.rb' script and will output
# one .md file for each chapter, organising them in folders corresponding to the book.
# Navigation on the top and bottom is also added.
#
#----------------------------------------------------------------------------------
# SETTINGS
#----------------------------------------------------------------------------------
# Setting a different Bible version:
# Using the abbreviation with the -v flag, you can call on a different version.
# It defaults to the "World English Bible", if you change the version,
# make sure to honour the copyright restrictions.
#----------------------------------------------------------------------------------


############################################################################################
# FOR TRANSLATORS
############################################################################################
# Copy the ./locales/en folder into the same folder, and rename it with the
# appropriate language code. Then translate each of the text files inside the
# new folder. Do NOT rename the text files, or your translations will break.
############################################################################################


show_help()
{
	echo "Usage: $0 [-sbeaicyh] [-v version]"
	echo "  -v version   Specify the Bible version to download (default = RSVCE)"
	echo "  -s    If available, use shorter book abbreviations"
	echo "  -b    Set words of Jesus in bold"
	echo "  -e    Include editorial headers"
	echo "  -a    Create an alias in the YAML front matter for each chapter title"
	echo "  -i    Show download information (i.e. verbose mode)"
	echo "  -c    Include inline navigation for the breadcrumbs plugin (e.g. 'up', 'next','previous')"
	echo "  -y    Print navigation for the breadcrumbs plugin (e.g. 'up', 'next','previous') in the frontmatter (YAML)"
	echo "  -l    Which language to use for file names, links, and titles"
	echo "  -h    Display help"
	exit 1
}

# Clear version variable if it exists and set defaults for others
ARG_VERSION="RSVCE"        # Which version to use from BibleGateway.com
ARG_ABBR_SHORT="false"   # Use shorter book abbreviations
ARG_BOLD_WORDS="false"   # Set words of Jesus in bold
ARG_HEADERS="false"      # Include editorial headers
ARG_ALIASES="false"      # Create an alias in the YAML front matter for each chapter title
ARG_VERBOSE="false"      # Show download progress for each chapter
ARG_BC_INLINE="false"    # Print breadcrumbs in the file
ARG_BC_YAML="false"      # Print breadcrumbs in the YAML
ARG_LANGUAGE="en"        # Which language translation to for file names, links, and titles

# Process command line args
while getopts 'v:sbeaicyl:?h' c; do
  case $c in
    v) ARG_VERSION=$OPTARG ;;
    s) ARG_ABBR_SHORT="true" ;;
    b) ARG_BOLD_WORDS="true" ;;
    e) ARG_HEADERS="true" ;;
    a) ARG_ALIASES="true" ;;
    i) ARG_VERBOSE="true" ;;
    c) ARG_BC_INLINE="true" ;;
		y) ARG_BC_YAML="true" ;;
		l) ARG_LANGUAGE=$OPTARG ;;
    h|?) show_help ;;
  esac
done

# Copyright disclaimer
echo "I confirm that I have checked and understand the copyright/license conditions for ${translation} and wish to continue downloading it in its entirety?"
select yn in "Yes" "No"; do
  case $yn in
    Yes ) break;;
    No ) exit;;
  esac
done

# Set translation folder
translation_folder="./locales/$ARG_LANGUAGE"

# TRANSLATION: The title of the Bible
bible_name=$(cat "$translation_folder/name.txt")
if [ "$?" -ne "0" ]; then
  echo "Language not found!"
  exit 1
fi

# TRANSLATION: Full names of the books of the Bible
declare -a book_array
i=0
while read line; do
  book_array[i]=$line
  ((++i))
done <"$translation_folder/books.txt"

# TRANSLATION: Abbreviated book names
declare -a abbr_array
if [[ $ARG_ABBR_SHORT == "true" ]]; then
  ABBR_FILE="booksAbbrShort.txt"
else
  ABBR_FILE="booksAbbr.txt"
fi
i=0
while read line; do
  abbr_array[i]=$line
  ((++i))
done <"$translation_folder/$ABBR_FILE"

# Book chapter list
declare -a chapter_array
chapter_array=(
  50  # Genesis
  40  # Exodus
  27  # Leviticus
  36  # Numbers
  34  # Deuteronomy
  24  # Joshua
  21  # Judges
  4   # Ruth

  31  # 1 Samuel
  24  # 2 Samuel
  22  # 1 Kings
  25  # 2 Kings
  29  # 1 Chronicles
  36  # 2 Chronicles
  10  # Ezra
  13  # Nehemiah

  14  # Tobit
  16  # Judith
  10  # Esther
  16  # 1 Maccabees
  15  # 2 Maccabees

  42   # Job
  150  # Psalms
  31   # Proverbs
  12   # Ecclesiastes
  8    # Song of Solomon

  19  # Wisdom
  51  # Sirach

  66  # Isaiah
  52  # Jeremiah
  5   # Lamentations
  6   # Baruch
  48  # Ezekiel
  14  # Daniel

  14  # Hosea
  3   # Joel
  9   # Amos
  1   # Obadiah
  4   # Jonah
  7   # Micah
  3   # Nahum
  3   # Habakkuk
  3   # Zephaniah
  2   # Haggai
  14  # Zechariah
  4   # Malachi

  28  # Matthew
  16  # Mark
  24  # Luke
  21  # John
  28  # Acts
  16  # Romans
  16  # 1 Corinthians
  13  # 2 Corinthians

  6   # Galatians
  6   # Ephesians
  4   # Philippians
  4   # Colossians
  5   # 1 Thessalonians
  3   # 2 Thessalonians
  6   # 1 Timothy
  4   # 2 Timothy
  3   # Titus
  1   # Philemon
  13  # Hebrews

  5   # James
  5   # 1 Peter
  3   # 2 Peter
  5   # 1 John
  1   # 2 John
  1   # 3 John
  1   # Jude
  22  # Revelation
)

# Find the longest book title (this might change in different languages)
# this will be used for verbose progress bar display
title_max=0
if [[ $ARG_VERBOSE == "true" ]]; then
  for ((i=0; i<73; i++)); do
    if [[ ${#book_array[i]} -gt $title_max ]]; then
      title_max=${#book_array[i]}
    fi
  done
fi

show_progress_bar()
{
  # Calculate completion percentage
  ((percentage=($2*100)/$3))

  # Create the progress bar
  ((bar_width=$percentage/5))
  local bar=""
  while [[ ${#bar} -lt $bar_width ]]; do
    bar="${bar}▩"
  done
  while [[ ${#bar} -lt 20 ]]; do
    bar="$bar "
  done

  # Normalize book name length
  local title="$1"
  while [[ ${#title} -lt $title_max ]]; do
    title=" $title"
  done

  # Normalize chapters complete number
  local completed="$2"
  if [[ ${#completed} -lt 2 ]]; then
    completed="0$completed"
  fi

  # Normalize chapters total number
  local total="$3"
  if [[ ${#total} -lt 2 ]]; then
    total="0$total"
  fi

  # Create the progress bar display
  progress_bar="$title —— Chapter $completed of $total —— |$bar| $percentage%"

  # start a new line
  if [[ $4 == "true" ]]; then
    echo -en "\n$progress_bar"
  # else the next progress bar will overwrite this one
  else
    echo -en "\r$progress_bar"
  fi
}

# Initialise the name of the Bible folder
bible_folder="$bible_name ($ARG_VERSION)"

# Initialise the main index file
echo -e "# $bible_folder" > "$bible_name.md"

if [[ $ARG_VERBOSE == "true" ]]; then
  echo -n "Starting download of $ARG_VERSION Bible."
fi

# Loop through the books of the Bible
for ((book_index=0; book_index<73; book_index++)); do

  book=${book_array[$book_index]}
  last_chapter=${chapter_array[$book_index]}
  abbreviation=${abbr_array[$book_index]}

  if [[ $ARG_VERBOSE == "true" ]]; then
    show_progress_bar "$book" 0 $last_chapter "true"
  fi

  # Add book to main index file
  echo -en "\n* $book:" >> "$bible_name.md"

  # Loop through each chapter of this book
  for ((chapter=1; chapter<=last_chapter; chapter++)); do

    # Counting the previous and next chapter for navigation
    ((prev_chapter=chapter-1))
    ((next_chapter=chapter+1))

    # File naming
    this_file="$abbreviation $chapter"
    prev_file="$abbreviation $prev_chapter"
    next_file="$abbreviation $next_chapter"

    # Add this chapter to the main index file
    echo -en " [[$this_file|$chapter]]" >> "$bible_name.md"

    # Set the appropriate flags for the 'bg2md_mod' script
    bg2md_flags="-c -f -l -r"
    if [[ $ARG_BOLD_WORDS == "true" ]]; then
      bg2md_flags="${bg2md_flags} -b"
    fi
    if [[ $ARG_HEADERS == "false" ]]; then
      bg2md_flags="${bg2md_flags} -e"
    fi

    book_no_spaces=$(echo "$book" | sed 's/ //g')
    # Use the bg2md script to read chapter contents
    chapter_content=$(ruby bg2md.rb $bg2md_flags -v $ARG_VERSION $book_no_spaces$chapter)

    # Delete unwanted headers from chapter content
    chapter_content=$(echo $chapter_content | sed 's/^(.*?)v1/v1/')

    # Use original header/footer navigation if another method isn't specified
    if [[ $ARG_BC_INLINE == "false" && $ARG_BC_YAML == "false" ]]; then
      navigation="[[$book]]"
      if [[ $chapter -gt 1 ]]; then
        navigation="[[$prev_file|← $book $prev_chapter]] | $navigation"
      fi
      if [[ $chapter -lt $last_chapter ]]; then
        navigation="$navigation | [[$next_file|$book $next_chapter →]]"
      fi

    # Navigation with INLINE BREADCRUMBS ENABLED
    elif [[ $ARG_BC_INLINE == "true" ]] ; then
      navigation="(up:: [[$book]])"
      if [[ $chapter -gt 1 ]]; then
        navigation="(previous:: [[$prev_file|← $book $prev_chapter]]) | $navigation"
      fi
      if [[ $chapter -lt $last_chapter ]]; then
        navigation="$navigation | (next:: [[$next_file|$book $next_chapter →]])"
      fi
    fi

    # Inject navigation for non-YAML output
    title="# $book $chapter"
    if [[ $ARG_BC_YAML == "true" ]]; then
      chapter_content="$title\n\n***\n$chapter_content"
    else
      chapter_content="$title\n\n$navigation\n\n***\n$chapter_content\n\n***\n\n$navigation"
    fi

    # Navigation with YAML breadcrumbs
    if [[ $ARG_BC_YAML == "true" ]]; then
      # create YAML breadcrumbs
      bc_yaml="\nup: ['$book']"
      if [[ $chapter -gt 1 ]]; then
        bc_yaml="\nprevious: ['$prev_file']$bc_yaml"
      fi
      if [[ $chapter -lt $last_chapter ]]; then
        bc_yaml="$bc_yaml\nnext: ['$next_file']"
      fi

      # Compile YAML output
      yaml="---"
      if $ARG_ALIASES -eq "true"; then
        yaml="$yaml\nAliases: [$book $chapter]"
      fi
      if $ARG_BC_YAML -eq "true"; then
        yaml="$yaml$bc_yaml"
      fi
      yaml="$yaml\n---\n"

      # Add YAML to export
      chapter_content="$yaml$chapter_content"
    fi

    # Create a new file for this chapter
    echo -e $chapter_content > "$this_file.md"

    # Create a folder for this book of the Bible if it doesn't exist, then move the new file into it
    # Compute 2-digit book index and prefixed folder name
    idx=$book_index          # zero-based in your loop
    num=$(( idx + 1 ))       # 1–73
    folder_index=$(printf "%02d - %s" "$num" "$book")
    book_dir="$bible_folder/$folder_index"

    mkdir -p "$book_dir"
    mv "$this_file".md "$book_dir"


    # Update progress in terminal
    if [[ $ARG_VERBOSE == "true" ]]; then
      show_progress_bar "$book" $chapter $last_chapter "false"
    fi

  done # End of chapter loop

  # Create an overview file inside the numbered book folder
  overview_file="links: [[$bible_name]]\n# $book\n\n[[$abbreviation 1|Start Reading →]]"

  # re-compute the folder name (must match what you did for chapters)
  num=$(( book_index + 1 ))
  folder_index=$(printf "%02d - %s" "$num" "$book")
  book_dir="$bible_folder/$folder_index"

  # write and move it into that numbered folder
  echo -e "$overview_file" > "$book.md"
  mv "$book.md" "$book_dir"


done # End of book loop

# Tidy up the Markdown files by removing unneeded headers and separating the verses
# with some blank space and an H6-level verse number.

# Using a perl one-liner here in order to help ensure that this works across platforms
# since the sed utility works differently on macOS and Linux variants. The perl should
# work consistently.

if [[ $ARG_VERBOSE == "true" ]]; then
  echo ""
  echo "Cleaning up the Markdown files."
fi

# Clear unnecessary headers
find . -name "*.md" -print0 | xargs -0 perl -pi -e 's/#.*(#####\D[1]\D)/#$1/g'

# Format verses into H6 headers
find . -name "*.md" -print0 | xargs -0 perl -pi -e 's/######\s([0-9]\s|[0-9][0-9]\s|[0-9][0-9][0-9]\s)/\n\n###### $1\n/g'

# Delete crossreferences
find . -name "*.md" -print0 | xargs -0 perl -pi -e 's/\<crossref intro.*crossref\>//g'

# Delete the Copyright About Help Our Network Social Preferences section
find . -type f -name '*.md' -print0 \
  | xargs -0 sed -i 's/AboutHelpOur NetworkSocialPreferences.*Preferences//g'

if [[ $ARG_VERBOSE == "true" ]]; then
  echo "Download complete. Markdown files ready for Obsidian import."
fi

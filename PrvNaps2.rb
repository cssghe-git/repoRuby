#
require 'open3'

# Essai avec open3
#
    scan_dir        = "/users/Gilbert/Temp/"
    scan_name       = "Tests.pdf"
    pdf_title       = " --pdftitle " + "Title"
    pdf_author      = " --pdfauthor " + "Author"
    pdf_subject     = " --pdfsubject " + "Subject"
    pdf_keywords    = " --pdfkeywords " + "K1, K2"
    scan_prog       = "/Applications/NAPS2.app/Contents/MacOS/NAPS2 console -v -o "
    cmdopen3        = "#{scan_prog}#{scan_dir}#{scan_name}#{pdf_title}#{pdf_author}#{pdf_subject}#{pdf_keywords} "

    stdin, stdout, stderr, wait_thr = Open3.popen3(cmdopen3)
    output = stdout.read
    error = stderr.read
    exit_status = wait_thr.value.exitstatus

    puts    "Log of scan => "
    puts    "- Output: #{output}"
    puts    "- Error: #{error}"
    puts    "- Exit status: #{exit_status}"
    puts    "End of scan log"

    exit


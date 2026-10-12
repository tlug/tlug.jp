---
title: Meeting
date: 1998-06-13T13:45:00+09:00
params:
  meetingType: meeting
  location: |-
    HSBC Securities Japan Ltd
    Tokyo Branch
    HSBC Building 10th floor
    11-1 Nihonbashi 3-chome, Chuo-ku, Tokyo 103-0027
---

## June Meeting Information

Lunch Meeting Time: 12:30  
Lunch Meeting Place: Tokyo JR Station Yaesu Chuo exit  
Lunch Eating Place: HSBC

## Meeting Topic

A talk on the Debian and RPM packaging systems for Linux was given by Stephen Turnbull and Scott Stone. Packaging systems allow easy installation and removal of Linux system software. The packaging systems come with powerful dependencies that inform the user what other programs are needed to ensure a functional Linux system. For example, the installation of the Japanese to English dicitionary xjdic is dependent on edict and kanjidic. An attempt to install xjdic with these packaging systems will result in a search of your system for edict and kanjidic. If the programs are not installed, the packaging system will tell you or install them for you over the Internet or from CD. The packaging systems allow the Linux user to find out information on every program on their system, learn the contents of software packages before installation, and find out what files were installed by what packages. Both rpm and dpkg come with a command line interface and a menu based interface.

How these packaging systems can be used for development of.rpm or.deb packages was also covered.

### Stephen Turnbull

Mr. Turnbull spoke on the Debian packaging system. He is a long time Linux user and an early member of TLUG. Mr. Turnbull contributes to the development of XEmacs, is the maintainer of the elisp Japanese to English dictionary interface to edict, edict.el, and is one of the principal authors for an upcoming book on Japanese support of Linux to be published by O'Reilly Japan. Mr. Turnbull holds a doctorate in economics from Stanford University and is a professor at Tsukuba University in Japan when he is not hacking Linux.

His presentation covered these areas:

1.  Package management
    1.  A fancier \`tar'
    2.  Distributions, dependencies, policies, and packages
2.  User tools
    1.  Package selection database: dselect
    2.  Package management (query, install, configure, remove): dpkg, alien
3.  Developer tools
    1.  Anatomy of a package
    2.  Building: dpkg-deb
    3.  Packaging: dkpg-deb
4.  Building packages
    1.  Hello
    2.  Custom Linux kernel
    3.  XEmacs 21
    4.  How should the XEmacs 21 package system coexist with Debian's?

### Scott Stone

Mr. Stone spoke on the RPM packaging system, a topic he is intimate with through years of experience. Mr. Stone is the primary developer of Pacific HiTech's TurboLinux and TurboLinux-J which uses the RPM packaging system for all its programs. Mr. Stone is an active TLUG member, is the primary system administrator for the TLUG server, and is an active contributor to the free software movement. The TurboLinux-J Linux distribution that Mr. Stone developed is the only commercially developed and supported Japanese Linux distribution. Additional information on TurboLinux can be found on the web at <http://www.pht.co.jp>. Mr. Stone studied computer science at the University of Utah.

His presentation covered RPMs, specifically:

- Basic usage of the commandline tool
  - installing
  - uninstalling
  - upgrading
  - querying
    - information
    - file listings
    - checking rpm ownership of files
    - install/uninstall script listings
    - Advanced header data retrieval
      - file permissions
      - copyright info
      - etc...
- Capabilities of the package management system
  - How it handles dependencies/conflicts
  - Version / Release numbering
  - Signatures
  - Etc..
    - Building RPMs
    - .spec file format
    - architecture considerations
    - Creating dependency lists
    - Signing packages w/ PGP
    - Rebuilding.(arch).rpm from.src.rpm

## Raffle

Some people won fabulous prizes. Voluntary donations of approximately 500 yen during the meeting were solicited. If you make a donation, it helps the awesome goals of TLUG. Free software remains free because of you. Also, you get a chance to win some great prizes.

3 UPS's  
3 486's  
5 monitors  
Keyboards  
A lot of power blocks  
3 Hubs  
switch boxes  
lots of ethernet cables, connectors, etc.

Finance information can be found in the accounting section of the TLUG home page.

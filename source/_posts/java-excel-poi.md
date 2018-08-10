---
layout: post
title: 使用POI读写Excel
date: 2017-05-27 14:15:06
tags: poi
categories: Java
---

比较出名的两个方案jxi和poi，由于jxi只适用Excel 2003，所以肯定选择poi，但是poi又跟android不兼容，不能通过maven依赖方式拉取，所以只能自己重新打包jar文件并导入到项目中才可以使用，在网上找了下找到个3-12版的，现在官网最新的是3-16，不过之前由于急着弄这个功能就没管了，后面找个时间自己打包下，jar包可以在下面链接找到

[https://github.com/izyhang/ExcelPoi](https://github.com/izyhang/ExcelPoi)

<!-- More -->

### 读写Excel
读写操作还是很常规的
``` java
InputStream is = new FileInputStream(filePath);
Workbook wookbook = new XSSFWorkbook(is);//Excel 2007
Sheet sheet = wookbook.getSheetAt(0);
Row row = sheet.getRow(0);
Cell cell = row.getCell(0);
...
```

### 取单元格内容
``` java
private static String getCellFormatValue(Cell cell) throws Exception {
        String value = "";
        // 判断当前Cell的Type
        switch (cell.getCellType()) {
            // 如果当前Cell的Type为NUMERIC
            case Cell.CELL_TYPE_NUMERIC:
                // 判断当前的cell是否为Date
                if (HSSFDateUtil.isCellDateFormatted(cell)) {
                    // 方法2：这样子的data格式是不带带时分秒的：2011-10-12
                    double date = cell.getNumericCellValue();
                    SimpleDateFormat sdf = new SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.CHINA);
                    value = sdf.format(HSSFDateUtil.getJavaDate(date));
                } else {
                    // 如果是纯数字通过NumberToTextConverter.toText(double)将double转成string
                    value = NumberToTextConverter.toText(cell.getNumericCellValue());
                }
                break;
            // 如果当前Cell的Type为STRING
            case Cell.CELL_TYPE_STRING:
                // 取得当前的Cell字符串
                value = cell.getStringCellValue();
                break;
            // 如果当前Cell的Type为BOOLEAN
            case Cell.CELL_TYPE_BOOLEAN:
                value = String.valueOf(cell.getBooleanCellValue());
                break;
        }
        return value;
    }
```
这里读纯数字用的是`NumberToTextConverter.toText`，具体看实际需求

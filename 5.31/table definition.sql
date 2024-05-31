-- appointment: table
CREATE TABLE `appointment` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `branch_id` int(10) unsigned NOT NULL,
  `profile_id` int(10) unsigned NOT NULL,
  `day` date NOT NULL,
  `period` int(11) NOT NULL COMMENT '将24h按15min划分',
  `status` int(11) NOT NULL DEFAULT '0' COMMENT '0coming, 1completed, -1canceled, -2timeout',
  `note` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `appointment_branch_id_fk` (`branch_id`),
  KEY `appointment_profile_id_fk` (`profile_id`),
  CONSTRAINT `appointment_branch_id_fk` FOREIGN KEY (`branch_id`) REFERENCES `branch` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `appointment_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profile` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8;

-- authority: table
CREATE TABLE `authority` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(20) NOT NULL,
  `parent_id` int(10) unsigned NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `system_parent_name` (`name`,`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8 COMMENT='可用于分配的权限';

-- after_add_authority: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_add_authority` AFTER INSERT ON `authority` FOR EACH ROW begin
    if (new.parent_id!=0) then
        insert into authority_sub_relation values (new.parent_id,new.id);
        insert into authority_sub_relation (parent_id, child_id)  select authority_sub_relation.parent_id,new.id from authority_sub_relation where child_id=new.parent_id;
    end if;
end;

-- authority_sub_relation: table
CREATE TABLE `authority_sub_relation` (
  `parent_id` int(10) unsigned NOT NULL,
  `child_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`parent_id`,`child_id`),
  KEY `authority_sub_relation_authority_id_fk2` (`child_id`),
  CONSTRAINT `authority_sub_relation_authority_id_fk` FOREIGN KEY (`parent_id`) REFERENCES `authority` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `authority_sub_relation_authority_id_fk2` FOREIGN KEY (`child_id`) REFERENCES `authority` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- branch: table
CREATE TABLE `branch` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `parent_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `branch_name_index` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COMMENT='公司架构，树状结构，控制数据访问';

-- No native definition for element: branch_name_index (index)

-- check_branch_add: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `check_branch_add` BEFORE INSERT ON `branch` FOR EACH ROW if new.parent_id > 0 and not exists(select * from branch where branch.id = NEW.parent_id)
       then signal sqlstate '45000' set message_text = 'parent path not exist';
    end if;

-- branch_sub_relation: table
CREATE TABLE `branch_sub_relation` (
  `parent_id` int(10) unsigned NOT NULL,
  `child_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`parent_id`,`child_id`),
  KEY `branch_sub_relation_child_id_index` (`child_id`),
  KEY `branch_sub_relation_parent_id_index` (`parent_id`),
  CONSTRAINT `branch_sub_relation_branch_child_id_fk` FOREIGN KEY (`child_id`) REFERENCES `branch` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `branch_sub_relation_branch_parent_id_fk` FOREIGN KEY (`parent_id`) REFERENCES `branch` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='将一个结点和它所有的祖先节点关联 ';

-- No native definition for element: branch_sub_relation_parent_id_index (index)

-- No native definition for element: branch_sub_relation_child_id_index (index)

-- category: table
CREATE TABLE `category` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(16) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `category_pk2` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;

-- cooperation: table
CREATE TABLE `cooperation` (
  `project_id` int(10) unsigned NOT NULL,
  `spu_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`project_id`,`spu_id`),
  KEY `cooperation_spu_id_fk` (`spu_id`),
  CONSTRAINT `cooperation_project_id_fk` FOREIGN KEY (`project_id`) REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `cooperation_spu_id_fk` FOREIGN KEY (`spu_id`) REFERENCES `spu` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='add a spu into a project';

-- add_project_spu_amount: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `add_project_spu_amount` AFTER INSERT ON `cooperation` FOR EACH ROW begin
    update project set spu_amount = spu_amount+1
        where
            (id in (select parent_id from project_sub_relation where child_id = new.project_id))
           or id=NEW.project_id;
end;

-- after_delete_cooperation: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_delete_cooperation` AFTER DELETE ON `cooperation` FOR EACH ROW begin
    update project set spu_amount = spu_amount-1
        where
            (id in(select parent_id from project_sub_relation where child_id = OLD.project_id))
            or id = OLD.project_id;
end;

-- customer: table
CREATE TABLE `customer` (
  `customer_id` int(10) unsigned DEFAULT NULL,
  `phone` char(16) DEFAULT NULL,
  `email` char(64) DEFAULT NULL,
  UNIQUE KEY `customer_id` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- inventory: table
CREATE TABLE `inventory` (
  `branch_id` int(10) unsigned NOT NULL,
  `sku_id` int(10) unsigned NOT NULL,
  `current` int(10) unsigned NOT NULL COMMENT '当前库存',
  `threshold` int(11) NOT NULL COMMENT '警戒阈值 -1表示不提醒',
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sku_id` (`sku_id`,`branch_id`),
  KEY `inventory_branch_id_fk` (`branch_id`),
  KEY `inventory_sku_id_index` (`sku_id`),
  CONSTRAINT `inventory_branch_id_fk` FOREIGN KEY (`branch_id`) REFERENCES `branch` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `inventory_sku_id_fk` FOREIGN KEY (`sku_id`) REFERENCES `sku` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8 COMMENT='sku inventory for branch';

-- No native definition for element: inventory_sku_id_index (index)

-- measurement: table
CREATE TABLE `measurement` (
  `mid` int(11) DEFAULT NULL,
  `profileID` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `height` float DEFAULT NULL,
  `weight` float DEFAULT NULL,
  `frontpic` longtext,
  `sidepic` longtext,
  `measureId` tinytext,
  `sizes` longtext,
  `frontProfileBody` longtext,
  `sideProfileBody` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- order: table
CREATE TABLE `order` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `code` char(32) NOT NULL,
  `status` char(16) NOT NULL COMMENT 'pending, failed, processing?, shipped, completed, cancelled',
  `user_id` int(10) unsigned NOT NULL,
  `payment_method` varchar(64) DEFAULT NULL,
  `origin` char(16) NOT NULL COMMENT '通过哪种途径创建的订单Avaialbe option: business app / client app / website  (but dont know how to detect this)',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `total_price` float NOT NULL,
  `note` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `oder_pk2` (`code`),
  KEY `oder_user_id_fk` (`user_id`),
  CONSTRAINT `oder_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- order_history: table
CREATE TABLE `order_history` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned NOT NULL,
  `summary` varchar(255) NOT NULL,
  `detail` text,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` int(10) unsigned NOT NULL COMMENT 'who did it',
  `company` char(50) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `order_history_order_id_fk` (`order_id`),
  KEY `order_history_user_id_fk` (`user_id`),
  CONSTRAINT `order_history_order_id_fk` FOREIGN KEY (`order_id`) REFERENCES `order` (`id`),
  CONSTRAINT `order_history_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- order_product: table
CREATE TABLE `order_product` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` int(10) unsigned NOT NULL,
  `spu_id` int(10) unsigned NOT NULL,
  `profile_id` int(10) unsigned NOT NULL,
  `price` float NOT NULL,
  `num` int(10) unsigned NOT NULL,
  `product_json` text,
  PRIMARY KEY (`id`),
  KEY `order_product_order_id_fk` (`order_id`),
  KEY `order_product_profile_id_fk` (`profile_id`),
  KEY `order_product_spu_id_fk` (`spu_id`),
  CONSTRAINT `order_product_order_id_fk` FOREIGN KEY (`order_id`) REFERENCES `order` (`id`),
  CONSTRAINT `order_product_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profile` (`id`),
  CONSTRAINT `order_product_spu_id_fk` FOREIGN KEY (`spu_id`) REFERENCES `spu` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

-- profile: table
CREATE TABLE `profile` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned DEFAULT NULL,
  `ENGname` tinytext,
  `CHIname` tinytext,
  `gender` char(20) DEFAULT NULL,
  `birth` date DEFAULT NULL,
  `qr_quote` tinytext,
  `code` varchar(32) DEFAULT NULL COMMENT '学号，员工号等',
  PRIMARY KEY (`id`),
  KEY `profile_project_id_fk` (`project_id`),
  KEY `profile_user_id_fk` (`user_id`),
  CONSTRAINT `profile_project_id_fk` FOREIGN KEY (`project_id`) REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `profile_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8;

-- project: table
CREATE TABLE `project` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `parent_id` int(10) unsigned NOT NULL COMMENT '父节点id,为0时为顶层，建议此时name=合作公司名',
  `partner` varchar(255) DEFAULT NULL COMMENT '合作方名称',
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '任何子孙节点被修改都将影响该字段',
  `description` text,
  `spu_amount` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'project及其subproject中包含的spu总数',
  PRIMARY KEY (`id`),
  UNIQUE KEY `project_pk2` (`name`,`parent_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1003 DEFAULT CHARSET=utf8 COMMENT='树状结构';

-- after_add_project: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_add_project` AFTER INSERT ON `project` FOR EACH ROW begin
    if (new.parent_id!=0) then
        insert into project_sub_relation values (new.parent_id,new.id);
        insert into project_sub_relation (parent_id, child_id)  select project_sub_relation.parent_id,new.id from project_sub_relation where child_id=new.parent_id;
    end if;
end;

-- prevent_delete_if_sub_project_exist: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `prevent_delete_if_sub_project_exist` BEFORE DELETE ON `project` FOR EACH ROW begin
    if exists(select * from project_sub_relation where project_sub_relation.parent_id=OLD.id)
        then signal sqlstate '45000' set message_text = 'You should delete all subprojects first';
    end if;
end;

-- project_sub_relation: table
CREATE TABLE `project_sub_relation` (
  `parent_id` int(10) unsigned NOT NULL,
  `child_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`child_id`,`parent_id`),
  KEY `project_sub_relation_project_parent_id_fk` (`parent_id`),
  CONSTRAINT `project_sub_relation_project_child_id_fk` FOREIGN KEY (`child_id`) REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `project_sub_relation_project_parent_id_fk` FOREIGN KEY (`parent_id`) REFERENCES `project` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='将一个结点和它所有的祖先节点关联 ';

-- record: table
CREATE TABLE `record` (
  `recordID` int(11) DEFAULT NULL,
  `userID` int(11) DEFAULT NULL,
  `profileID` int(11) DEFAULT NULL,
  `mid` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- role: table
CREATE TABLE `role` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `branch_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `role_pk2` (`name`,`branch_id`),
  KEY `role_branch_id_index` (`branch_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8 COMMENT='用于权限管理的角色';

-- No native definition for element: role_branch_id_index (index)

-- role_to_authority: table
CREATE TABLE `role_to_authority` (
  `role_id` int(10) unsigned NOT NULL,
  `authority_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`authority_id`,`role_id`),
  KEY `role_to_authority_authority_id_index` (`authority_id`),
  KEY `role_to_authority_role_id_index` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='middle table for role and authority';

-- No native definition for element: role_to_authority_role_id_index (index)

-- No native definition for element: role_to_authority_authority_id_index (index)

-- screen_rule_model: table
CREATE TABLE `screen_rule_model` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `screen_rule` text NOT NULL COMMENT 'json data',
  `size_code_to_name` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;

-- shopping_cart: table
CREATE TABLE `shopping_cart` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `sku_id` int(10) unsigned NOT NULL,
  `profile_id` int(10) unsigned NOT NULL,
  `num` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `shopping_cart_pk` (`profile_id`,`sku_id`,`user_id`),
  KEY `shopping_cart_sku_id_fk` (`sku_id`),
  KEY `shopping_cart_user_id_fk` (`user_id`),
  CONSTRAINT `shopping_cart_profile_id_fk` FOREIGN KEY (`profile_id`) REFERENCES `profile` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `shopping_cart_sku_id_fk` FOREIGN KEY (`sku_id`) REFERENCES `sku` (`id`),
  CONSTRAINT `shopping_cart_user_id_fk` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

-- sku: table
CREATE TABLE `sku` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `code` char(16) NOT NULL,
  `spu_id` int(10) unsigned NOT NULL,
  `material` varchar(255) DEFAULT NULL,
  `size` varchar(8) DEFAULT NULL,
  `color` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sku_pk` (`material`,`spu_id`,`size`,`color`),
  KEY `sku_spu_id_fk` (`spu_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8;

-- No native definition for element: sku_spu_id_fk (index)

-- spu: table
CREATE TABLE `spu` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `code` char(16) NOT NULL,
  `type` tinyint(1) NOT NULL COMMENT '0 is MTM, 1 is RTW',
  `category_id` int(10) unsigned NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` text,
  `image_path_list` text COMMENT 'json list',
  `size_chart` text COMMENT 'json data\nExample:\n{ \n"S": {"Bust": 99.1, ...}, \n"M": {"Bust": 103.1, ...},\n...\n}',
  `pattern_path` varchar(255) DEFAULT NULL,
  `standard_price` float DEFAULT NULL,
  `sale_price` float DEFAULT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `screen_rule` text COMMENT 'used for size recommendation, json data\nExample:{\n  "idealEase":{"Bust": 6,...},\n  "absFitValue2FitValue"[\n    {\n      "absFitValueName": "Bust",\n      "fitValueName": "Bust",\n      "easeValueName": "Bust",\n      "rangeNode": [17, 8, 4, -1],\n      "rangeWeight": [2.5, 2, 1, 1.8, 3]\n    },{\n      "absFitValueName": "Shoulder",\n      "fitValueName": "ShoulderMinus",\n      "easeValueName": "Shoulder",\n      "rangeNode": [10, 5],\n      "rangeWeight": [0, 0.8, 1.41]\n    }, \n    ...\n  ],\n  "allWeighting":{"Bust": 1.0, "ShoulderMinus": 0,},\n  "easeThreshold":{"Bust": -1, "Waist": -1}\n}\n',
  `size_code_to_name` text COMMENT 'json data,\nexample:\n{"sizeCode": "bodyPartName",...}',
  `rule_name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `spu_code` (`code`),
  KEY `spu_category_id_fk` (`category_id`),
  CONSTRAINT `spu_category_id_fk` FOREIGN KEY (`category_id`) REFERENCES `category` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=302 DEFAULT CHARSET=utf8 COMMENT='standard product unit';

-- staff: table
CREATE TABLE `staff` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL COMMENT '员工账号',
  `name` varchar(255) DEFAULT NULL COMMENT '员工姓名',
  `code` varchar(32) DEFAULT NULL COMMENT 'for example:内部员工号',
  `modified_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '当token需要更新时改变',
  `id_card` char(32) DEFAULT NULL COMMENT '身份证号之类的',
  PRIMARY KEY (`id`),
  KEY `staff_user_id_fk` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=74 DEFAULT CHARSET=utf8;

-- No native definition for element: staff_user_id_fk (index)

-- staff_to_role: table
CREATE TABLE `staff_to_role` (
  `staff_id` int(10) unsigned NOT NULL,
  `role_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`staff_id`,`role_id`),
  KEY `staff_to_role_role_id_fk` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='assign a role to a staff';

-- No native definition for element: staff_to_role_role_id_fk (index)

-- after_add_staff_role: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_add_staff_role` AFTER INSERT ON `staff_to_role` FOR EACH ROW begin
    update staff set modified_time=current_timestamp where id=new.staff_id;
end;

-- after_delete_staff_role: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_delete_staff_role` AFTER DELETE ON `staff_to_role` FOR EACH ROW begin
    update staff set modified_time=current_timestamp where id=old.staff_id;
end;

-- user: table
CREATE TABLE `user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `password` char(64) NOT NULL,
  `email` char(64) DEFAULT NULL,
  `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_verified` tinyint(1) NOT NULL DEFAULT '0' COMMENT '需通过邮箱或手机验证',
  `modified_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `nickname` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_email_index` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=4227 DEFAULT CHARSET=utf8;

-- No native definition for element: user_email_index (index)

-- check_user_add: trigger
CREATE DEFINER=`root`@`localhost` trigger check_user_add
    before insert
    on user
    for each row
begin
    if new.email=''
        then signal sqlstate '45000' set message_text = 'email needed';
    end if;
    if exists(select * from user where user.is_verified=TRUE and user.email=new.email)
        then signal sqlstate '45000' set message_text = 'email has been registered';
    end if;
    if exists(select * from user where user.is_verified=FALSE and user.email=new.email)
        then signal sqlstate '45000' set message_text = 'email has been registered,but has been not verified';
    end if;
end;

-- check_user_update: trigger
CREATE DEFINER=`root`@`localhost` trigger check_user_update
    before update
    on user
    for each row
begin
    if new.email!=old.email
        then if exists(select * from user where user.email=new.email and user.id !=new.id)
            then signal sqlstate '45000' set message_text = 'email has been registered';
        end if;
    end if;
end;

-- after_user_update: trigger
CREATE DEFINER=`root`@`localhost` TRIGGER `after_user_update` AFTER UPDATE ON `user` FOR EACH ROW begin
    update staff set modified_time=current_timestamp where user_id=new.id;
end;


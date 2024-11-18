-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public IS 'standard public schema';

-- DROP SEQUENCE public.photoid_seq;

CREATE SEQUENCE public.photoid_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1
	CACHE 1
	NO CYCLE;-- public.clientinfo definition

-- Drop table

-- DROP TABLE public.clientinfo;

CREATE TABLE public.clientinfo (
	client varchar(255) NOT NULL,
	address varchar(255) NULL,
	email varchar(255) NULL,
	phone varchar(255) NULL,
	username varchar(255) NULL,
	CONSTRAINT clientinfo_pk PRIMARY KEY (client)
);


-- public."increment" definition

-- Drop table

-- DROP TABLE public."increment";

CREATE TABLE public."increment" (
	date_column varchar(7) NULL,
	counter int4 DEFAULT 1 NULL,
	CONSTRAINT unique_date UNIQUE (date_column)
);


-- public.clientdestination definition

-- Drop table

-- DROP TABLE public.clientdestination;

CREATE TABLE public.clientdestination (
	client varchar(255) NULL,
	destination varchar(255) NULL,
	CONSTRAINT clientdestination_clientinfo_fk FOREIGN KEY (client) REFERENCES public.clientinfo(client)
);


-- public.packinglist definition

-- Drop table

-- DROP TABLE public.packinglist;

CREATE TABLE public.packinglist (
	shipment_date varchar NOT NULL,
	client varchar NOT NULL,
	packing_id varchar NOT NULL,
	tracking_id varchar NOT NULL,
	status varchar NOT NULL,
	carrier varchar NOT NULL,
	notes varchar NOT NULL,
	CONSTRAINT packinglist_pk PRIMARY KEY (packing_id),
	CONSTRAINT packinglist_clientinfo_fk FOREIGN KEY (client) REFERENCES public.clientinfo(client)
);


-- public.packinglistitems definition

-- Drop table

-- DROP TABLE public.packinglistitems;

CREATE TABLE public.packinglistitems (
	packing_id varchar NOT NULL,
	crate_id varchar NOT NULL,
	po_item_id varchar NOT NULL,
	crate_qty varchar NOT NULL,
	crate_length varchar NOT NULL,
	crate_width varchar NOT NULL,
	crate_height varchar NOT NULL,
	crate_weight varchar NOT NULL,
	notes varchar NOT NULL,
	CONSTRAINT packinglistitems_packinglist_fk FOREIGN KEY (packing_id) REFERENCES public.packinglist(packing_id)
);


-- public.purchaseorders definition

-- Drop table

-- DROP TABLE public.purchaseorders;

CREATE TABLE public.purchaseorders (
	po varchar(255) NOT NULL,
	destination varchar(255) NULL,
	vendor varchar(255) NULL,
	shippingmethod varchar(255) NULL,
	notes varchar(255) NULL,
	client varchar NULL,
	CONSTRAINT purchaseorders_pk PRIMARY KEY (po),
	CONSTRAINT purchaseorders_clientinfo_fk FOREIGN KEY (client) REFERENCES public.clientinfo(client)
);


-- public.warehousereceipt definition

-- Drop table

-- DROP TABLE public.warehousereceipt;

CREATE TABLE public.warehousereceipt (
	wr_id varchar(255) NOT NULL,
	client varchar(255) NULL,
	carrier varchar(255) NULL,
	tracking_id varchar(255) NULL,
	"date" timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
	received_by varchar(255) NULL,
	hazmat varchar(255) NULL,
	hazcode varchar(255) NULL,
	notes varchar(255) NULL,
	wr_po varchar(255) NOT NULL,
	mr_check bool DEFAULT false NOT NULL,
	CONSTRAINT warehousereceipt_pkey PRIMARY KEY (wr_id),
	CONSTRAINT warehousereceipt_clientinfo_fk FOREIGN KEY (client) REFERENCES public.clientinfo(client)
);


-- public.warehousereceipt_table definition

-- Drop table

-- DROP TABLE public.warehousereceipt_table;

CREATE TABLE public.warehousereceipt_table (
	wr_id varchar(255) NULL,
	box_id varchar(255) NULL,
	box_type varchar(255) NULL,
	b_length int4 NOT NULL,
	b_width int4 NOT NULL,
	b_height int4 NOT NULL,
	b_location varchar(255) NULL,
	b_weight int4 NOT NULL,
	CONSTRAINT warehousereceipt_table_wr_id_fkey FOREIGN KEY (wr_id) REFERENCES public.warehousereceipt(wr_id)
);


-- public.materialreceipt definition

-- Drop table

-- DROP TABLE public.materialreceipt;

CREATE TABLE public.materialreceipt (
	wr_id varchar(255) NULL,
	"date" timestamp DEFAULT now() NULL,
	entered_by varchar(255) NULL,
	notes varchar(255) NULL,
	CONSTRAINT materialreceipt_wr_id_fkey FOREIGN KEY (wr_id) REFERENCES public.warehousereceipt(wr_id)
);


-- public.materialreceipt_table definition

-- Drop table

-- DROP TABLE public.materialreceipt_table;

CREATE TABLE public.materialreceipt_table (
	wr_id varchar(255) NULL,
	quantity_recieved varchar(255) NULL,
	boxid varchar(255) NULL,
	po_item_id int4 NULL,
	CONSTRAINT materialreceipt_table_wr_id_fkey FOREIGN KEY (wr_id) REFERENCES public.warehousereceipt(wr_id)
);


-- public.photos definition

-- Drop table

-- DROP TABLE public.photos;

CREATE TABLE public.photos (
	photoid int4 DEFAULT nextval('photoid_seq'::regclass) NOT NULL,
	s3url varchar NOT NULL,
	description varchar NULL,
	uploadtimestamp timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
	wr_id varchar NOT NULL,
	short_over bool DEFAULT false NOT NULL,
	CONSTRAINT photos_pkey PRIMARY KEY (s3url),
	CONSTRAINT unique_photoid UNIQUE (photoid),
	CONSTRAINT photos_warehousereceipt_fk FOREIGN KEY (wr_id) REFERENCES public.warehousereceipt(wr_id)
);


-- public.purchaseorderitems definition

-- Drop table

-- DROP TABLE public.purchaseorderitems;

CREATE TABLE public.purchaseorderitems (
	client varchar(255) NULL,
	po varchar(255) NULL,
	po_item_id int4 NOT NULL,
	part_id varchar NOT NULL,
	description varchar(255) NULL,
	quantity int4 NOT NULL,
	costperunit int4 NOT NULL,
	qty_received int4 DEFAULT 0 NOT NULL,
	CONSTRAINT purchaseorderitems_clientinfo_fk FOREIGN KEY (client) REFERENCES public.clientinfo(client),
	CONSTRAINT purchaseorderitems_purchaseorders_fk FOREIGN KEY (po) REFERENCES public.purchaseorders(po)
);



-- DROP FUNCTION public.create_purchaseorder_if_not_exists();

CREATE OR REPLACE FUNCTION public.create_purchaseorder_if_not_exists()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Check if the purchase order exists
    IF NOT EXISTS (
        SELECT 1 FROM purchaseorders
        WHERE client = NEW.client AND po = NEW.po
    ) THEN
        -- Insert a new purchase order with default or required values
        INSERT INTO purchaseorders (client, po, destination, vendor, shippingmethod, notes)
        VALUES (
            NEW.client,
            NEW.po,
            'Default Destination',  -- Replace with actual value or default
            'Default Vendor',       -- Replace with actual value or default
            'Default Shipping',     -- Replace with actual value or default
            'Auto-generated PO'     -- Replace with actual value or default
        );
    END IF;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION public.generate_wr_id();

CREATE OR REPLACE FUNCTION public.generate_wr_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    new_item_number INT;
BEGIN
    -- Find the highest item number for the current day (if any exist)
    -- Cast the substring to an integer only when it's not null or empty
    SELECT COALESCE(MAX(CAST(NULLIF(SUBSTRING(wr_id FROM 9), '') AS INT)), 0) + 1
    INTO new_item_number
    FROM warehousereceipt
    WHERE TO_CHAR(NEW.date, 'YYMMDD') = TO_CHAR(date, 'YYMMDD');

    -- Assign the new wr_id in the format YYMMDD-item
    NEW.wr_id := CONCAT(TO_CHAR(NEW.date, 'YYMMDD'), '-', new_item_number);

    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION public.insert_initial_data_into_purchaseorderitems();

CREATE OR REPLACE FUNCTION public.insert_initial_data_into_purchaseorderitems()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Check if the record already exists in purchaseorderitems
    IF NOT EXISTS (
        SELECT 1 
        FROM purchaseorderitems 
        WHERE client = NEW.client AND po = NEW.po
    ) THEN
        -- Insert into purchaseorderitems table if no matching client and po
        INSERT INTO purchaseorderitems (client, po)
        VALUES (NEW.client, NEW.po);

        -- Optional: Debugging statement
        RAISE NOTICE 'Inserted new row into purchaseorderitems: % %', NEW.client, NEW.po;
    ELSE
        -- Optional: Debugging statement
        RAISE NOTICE 'Duplicate avoided for: % %', NEW.client, NEW.po;
    END IF;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION public.insert_into_purchaseorderitems();

CREATE OR REPLACE FUNCTION public.insert_into_purchaseorderitems()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Insert into purchaseorderitems table with default values for other columns
    INSERT INTO purchaseorderitems (client, po)
    VALUES (NEW.client, NEW.po);
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION public.remove_duplicates_from_purchaseorderitems();

CREATE OR REPLACE FUNCTION public.remove_duplicates_from_purchaseorderitems()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Check if the record already exists in purchaseorderitems to prevent duplication
    IF NOT EXISTS (
        SELECT 1 
        FROM purchaseorderitems 
        WHERE client = NEW.client AND po = NEW.po
    ) THEN
        -- Insert into purchaseorderitems table if no matching client and po
        INSERT INTO purchaseorderitems (client, po)
        VALUES (NEW.client, NEW.po);

        -- Optional: Debugging statement
        RAISE NOTICE 'Inserted new row into purchaseorderitems: % %', NEW.client, NEW.po;
    ELSE
        -- Optional: Debugging statement
        RAISE NOTICE 'Duplicate avoided for: % %', NEW.client, NEW.po;
    END IF;
    RETURN NEW;
END;
$function$
;

-- DROP FUNCTION public.reset_increment_table();

CREATE OR REPLACE FUNCTION public.reset_increment_table()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Format the date as YYMMDD-
    UPDATE increment
    SET date_column = TO_CHAR(CURRENT_DATE, 'YYMMDD-'),
        counter = 1;
END;
$function$
;

-- DROP FUNCTION public.wr_id();

CREATE OR REPLACE FUNCTION public.wr_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    new_item_number INT;
BEGIN
    -- Find the highest item number for the current day (if any exist)
    SELECT COALESCE(MAX(CAST(SUBSTRING(wr_id FROM 9) AS INT)), 0) + 1
    INTO new_item_number
    FROM warehousereceipt
    WHERE TO_CHAR(NEW.date, 'YYMMDD') = TO_CHAR(date, 'YYMMDD');

    -- Assign the new wr_id in the format YYMMDD-item
    NEW.wr_id := CONCAT(TO_CHAR(NEW.date, 'YYMMDD'), '-', new_item_number);

    RETURN NEW;
END;
$function$
;
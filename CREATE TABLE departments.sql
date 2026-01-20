CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100) NOT NULL
);

CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    salary NUMBER(10,2) CHECK (salary > 0),
    department_id NUMBER NOT NULL,
    hire_date DATE DEFAULT SYSDATE,
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

CREATE TABLE salary_history (
    history_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL,
    old_salary NUMBER(10,2),
    new_salary NUMBER(10,2),
    change_date DATE DEFAULT SYSDATE,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE SEQUENCE dept_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE emp_seq START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE salary_history_seq START WITH 1 INCREMENT BY 1;

INSERT INTO departments VALUES (dept_seq.NEXTVAL, 'IT');
INSERT INTO departments VALUES (dept_seq.NEXTVAL, 'HR');
INSERT INTO departments VALUES (dept_seq.NEXTVAL, 'Finance');

SELECT * FROM departments;

INSERT INTO employees (
    employee_id, first_name, last_name, email, salary, department_id
) VALUES (
    emp_seq.NEXTVAL, 'John', 'Doe', 'john@example.com', 50000, 1
);

INSERT INTO employees (
    employee_id, first_name, last_name, email, salary, department_id
) VALUES (
    emp_seq.NEXTVAL, 'Sara', 'Smith', 'sara@example.com', 60000, 1
);


SELECT * FROM employees;


CREATE OR REPLACE PACKAGE emp_management IS

    -- Hire a new employee
    PROCEDURE hire_employee(
        p_emp_id       IN NUMBER,
        p_first_name   IN VARCHAR2,
        p_last_name    IN VARCHAR2,
        p_email        IN VARCHAR2,
        p_salary       IN NUMBER,
        p_dept_id      IN NUMBER
    );

    -- Update existing employee salary
    PROCEDURE update_salary(
        p_emp_id      IN NUMBER,
        p_new_salary  IN NUMBER
    );

    -- Calculate bonus for an employee
    FUNCTION calculate_bonus(
        p_emp_id        IN NUMBER,
        p_bonus_percent IN NUMBER
    ) RETURN NUMBER;

    -- Terminate (delete) employee
    PROCEDURE terminate_employee(
        p_emp_id   IN NUMBER
    );

END emp_management;
/


CREATE OR REPLACE PACKAGE BODY emp_management IS

    -- Hire a new employee
    PROCEDURE hire_employee(
        p_emp_id       IN NUMBER,
        p_first_name   IN VARCHAR2,
        p_last_name    IN VARCHAR2,
        p_email        IN VARCHAR2,
        p_salary       IN NUMBER,
        p_dept_id      IN NUMBER
    )
    IS
    BEGIN
        INSERT INTO employees (
            employee_id, first_name, last_name, email, salary, department_id
        )
        VALUES (
            p_emp_id, p_first_name, p_last_name, p_email, p_salary, p_dept_id
        );
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20002, 'Employee ID or Email already exists');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20003, 'Hire failed: ' || SQLERRM);
    END hire_employee;


    -- Update employee salary
    PROCEDURE update_salary(
        p_emp_id      IN NUMBER,
        p_new_salary  IN NUMBER
    )
    IS
        v_old_salary employees.salary%TYPE;
    BEGIN
        SELECT salary INTO v_old_salary
        FROM employees
        WHERE employee_id = p_emp_id;

        UPDATE employees
        SET salary = p_new_salary
        WHERE employee_id = p_emp_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Employee not found');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Salary update failed: ' || SQLERRM);
    END update_salary;


    -- Calculate bonus for employee
    FUNCTION calculate_bonus(
        p_emp_id        IN NUMBER,
        p_bonus_percent IN NUMBER
    ) RETURN NUMBER
    IS
        v_salary employees.salary%TYPE;
    BEGIN
        SELECT salary INTO v_salary
        FROM employees
        WHERE employee_id = p_emp_id;

        RETURN v_salary * p_bonus_percent;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006, 'Employee not found');
    END calculate_bonus;


    -- Terminate employee
    PROCEDURE terminate_employee(
        p_emp_id   IN NUMBER
    )
    IS
    BEGIN
        DELETE FROM employees
        WHERE employee_id = p_emp_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'Employee not found');
        END IF;
    END terminate_employee;

END emp_management;
/




CREATE OR REPLACE TRIGGER emp_salary_audit
AFTER UPDATE OF salary ON employees
FOR EACH ROW
BEGIN
    INSERT INTO salary_history(
        history_id,
        employee_id,
        old_salary,
        new_salary,
        change_date
    ) VALUES (
        salary_history_seq.NEXTVAL,
        :NEW.employee_id,
        :OLD.salary,
        :NEW.salary,
        SYSDATE
    );
END;
/


CREATE OR REPLACE TRIGGER emp_hire_date_check
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF :NEW.hire_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Hire date cannot be in future!');
    END IF;
END;
/


INSERT INTO employees VALUES (
    emp_seq.NEXTVAL, 'Test', 'User', 'future@example.com', 30000, 1, SYSDATE + 5
);


BEGIN
    emp_management.hire_employee(
        p_emp_id => 102,
        p_first_name => 'Sara',
        p_last_name => 'Lee',
        p_email => 'sara@example.com',
        p_salary => 50000,
        p_dept_id => 1
    );
END;
/


BEGIN
    emp_management.update_salary(102, 60000);
END;
/


SELECT * FROM salary_history WHERE employee_id = 102;
